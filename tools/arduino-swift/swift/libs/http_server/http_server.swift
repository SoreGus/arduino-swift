//
//  http_server.swift
//  ArduinoSwift - Minimal HTTP Server (UNO R4 WiFi)
//
//  A tiny HTTP/1.1 server designed for Embedded Swift environments.
//  It runs cooperatively (tick-based) and integrates with ArduinoRuntime
//  via ArduinoTickable.
//
//  Design goals:
//  - No Foundation dependency (no CharacterSet, split, trimming, JSONSerialization, etc.)
//  - Avoid Unicode normalization-heavy APIs to keep the embedded link clean
//  - Parse HTTP requests using raw bytes (ASCII/UTF-8) with small fixed limits
//  - Support basic routing for GET and POST
//  - Provide a small JSON encoder without Dictionaries (ordered tuples instead)
//
//  How it works:
//  - The C++ side exposes a small C-ABI for an underlying WiFi server/client.
//  - This Swift layer polls for an available client and reads bytes into a buffer.
//  - It detects the end of headers (\r\n\r\n), parses the request line + headers,
//    optionally reads Content-Length bytes, routes the request, writes a response,
//    and closes the connection.
//
//  Limitations:
//  - One request per connection, Connection: close
//  - Body is read only via Content-Length (no chunked transfer encoding)
//  - Minimal parsing, intended for LAN/dev usage on microcontrollers
//

public enum HTTPMethod: U8, Sendable {
    case get  = 1
    case post = 2
}

public struct HTTPHeader: Sendable {
    public let name: [U8]
    public let value: [U8]
}

public struct HTTPRequest: Sendable {
    public let method: HTTPMethod
    public let path: [U8]
    public let headers: [HTTPHeader]
    public let body: [U8]

    public func pathString() -> String { asciiString(path) }

    public func header(_ name: StaticString) -> [U8]? {
        let n = staticUTF8(name)
        for h in headers {
            if asciiCaseInsensitiveEqual(h.name, n) { return h.value }
        }
        return nil
    }

    public func contentLength() -> Int {
        if let v = header("Content-Length") {
            return asciiParseInt(v) ?? 0
        }
        return 0
    }
}

public struct HTTPResponse: Sendable {
    public let status: I32
    public let contentType: [U8]
    public let body: [U8]

    public static func response(
        _ text: String,
        status: I32 = 200,
        contentType: String = "text/plain; charset=utf-8"
    ) -> HTTPResponse {
        .init(status: status, contentType: Array(contentType.utf8), body: Array(text.utf8))
    }

    public static func response(
        _ data: [U8],
        status: I32 = 200,
        contentType: String = "application/octet-stream"
    ) -> HTTPResponse {
        .init(status: status, contentType: Array(contentType.utf8), body: data)
    }

    public static func json(_ v: JSONValue, status: I32 = 200) -> HTTPResponse {
        .init(
            status: status,
            contentType: Array("application/json; charset=utf-8".utf8),
            body: v.encodeUTF8()
        )
    }
}

// ============================================================
// Lightweight JSON encoder (no Foundation)
// ============================================================

public enum JSONValue: Sendable {
    case null
    case bool(Bool)
    case number(I32)
    case string(String)
    case array([JSONValue])
    case object([(String, JSONValue)])

    public func encodeUTF8() -> [U8] {
        var out: [U8] = []
        out.reserveCapacity(64)
        encode(into: &out)
        return out
    }

    private func encode(into out: inout [U8]) {
        switch self {
        case .null:
            out += Array("null".utf8)

        case .bool(let b):
            out += Array((b ? "true" : "false").utf8)

        case .number(let n):
            out += asciiInt(n)

        case .string(let s):
            out.append(0x22)
            encodeJSONString(s, into: &out)
            out.append(0x22)

        case .array(let arr):
            out.append(0x5B)
            var first = true
            for v in arr {
                if !first { out.append(0x2C) }
                first = false
                v.encode(into: &out)
            }
            out.append(0x5D)

        case .object(let obj):
            out.append(0x7B)
            var first = true
            for (k, v) in obj {
                if !first { out.append(0x2C) }
                first = false
                out.append(0x22)
                encodeJSONString(k, into: &out)
                out.append(0x22)
                out.append(0x3A)
                v.encode(into: &out)
            }
            out.append(0x7D)
        }
    }
}

@inline(__always)
private func encodeJSONString(_ s: String, into out: inout [U8]) {
    for b in s.utf8 {
        switch b {
        case 0x5C: out += Array("\\\\".utf8)
        case 0x22: out += Array("\\\"".utf8)
        case 0x0A: out += Array("\\n".utf8)
        case 0x0D: out += Array("\\r".utf8)
        case 0x09: out += Array("\\t".utf8)
        default:   out.append(b)
        }
    }
}

// ============================================================
// HTTPServer (ArduinoTickable)
// ============================================================

public final class HTTPServer: ArduinoTickable {

    public typealias Handler = (HTTPRequest) -> HTTPResponse
    public typealias FailureHandler = (HTTPServerError) -> Void

    public struct Route: Sendable {
        public let method: HTTPMethod
        public let path: [U8]
        public let handler: Handler

        public init(method: HTTPMethod, path: [U8], handler: @escaping Handler) {
            self.method = method
            self.path = path
            self.handler = handler
        }
    }

    public struct HTTPServerError: Sendable {
        public let message: String
        public init(_ message: String) { self.message = message }
    }

    private var routes: [Route] = []
    private var failure: FailureHandler?

    private var port: UInt16 = 80
    private var running: Bool = false

    private var rx: [U8] = []
    private var headerEndIndex: Int = -1
    private var expectedBodyLen: Int = 0

    private let headerMaxBytes: Int = 2048
    private let bodyMaxBytes: Int = 2048
    private let bodyWaitMs: U32 = 8000
    private let pollMs: U32 = 5

    private var nextPollAt: U32 = 0
    private var bodyWaitStart: U32 = 0

    public init() {}

    public func onFailure(_ cb: @escaping FailureHandler) {
        self.failure = cb
    }

    public func get(_ path: String, _ handler: @escaping Handler) {
        routes.append(.init(method: .get, path: Array(path.utf8), handler: handler))
    }

    public func post(_ path: String, _ handler: @escaping Handler) {
        routes.append(.init(method: .post, path: Array(path.utf8), handler: handler))
    }

    @discardableResult
    public func start(port: UInt16 = 80) -> Bool {
        self.port = port
        let rc = arduino_http_server_begin(port)
        if rc != 1 {
            failure?(.init("arduino_http_server_begin failed"))
            running = false
            return false
        }
        running = true
        resetRx()
        return true
    }

    public func stop() {
        arduino_http_server_end()
        running = false
        resetRx()
    }

    public func addToRuntime() { ArduinoRuntime.add(self) }

    public func tick() {
        if !running { return }

        let now = arduino_millis()
        if now < nextPollAt { return }
        nextPollAt = now &+ pollMs

        if arduino_http_server_client_available() != 1 {
            return
        }

        readAvailableIntoRx()

        if headerEndIndex < 0 {
            headerEndIndex = findHeaderEnd(rx)
            if headerEndIndex >= 0 {
                expectedBodyLen = parseContentLength(rx, headerEndIndex: headerEndIndex) ?? 0
                if expectedBodyLen > bodyMaxBytes { expectedBodyLen = bodyMaxBytes }
                bodyWaitStart = arduino_millis()
            } else {
                if rx.count > headerMaxBytes {
                    failAndClose("Header too large")
                }
                return
            }
        }

        let headerEnd = headerEndIndex
        let haveBodyBytes = rx.count - headerEnd

        if expectedBodyLen > 0 && haveBodyBytes < expectedBodyLen {
            if (arduino_millis() &- bodyWaitStart) > bodyWaitMs {
                failAndClose("Body timeout (need \(expectedBodyLen), have \(haveBodyBytes))")
            }
            return
        }

        guard let req = parseRequest(rx, headerEndIndex: headerEndIndex, bodyLen: expectedBodyLen) else {
            failAndClose("Bad request")
            return
        }

        let resp = route(req) ?? .response("Not Found\n", status: 404, contentType: "text/plain; charset=utf-8")
        writeResponse(resp)
        arduino_http_server_client_stop()
        resetRx()
    }

    private func resetRx() {
        rx.removeAll(keepingCapacity: true)
        headerEndIndex = -1
        expectedBodyLen = 0
        bodyWaitStart = 0
    }

    private func failAndClose(_ msg: String) {
        failure?(.init(msg))
        arduino_http_server_client_stop()
        resetRx()
    }

    private func route(_ req: HTTPRequest) -> HTTPResponse? {
        for r in routes {
            if r.method == req.method && r.path == req.path {
                return r.handler(req)
            }
        }
        return nil
    }

    private func readAvailableIntoRx() {
        var safety = 0
        while safety < 16 {
            safety += 1

            let av = arduino_http_server_client_available_bytes()
            if av <= 0 { break }

            let maxRead = min(Int(av), 256)

            var tmp = [U8](repeating: 0, count: maxRead)
            let cap = U32(maxRead)

            let n: I32 = tmp.withUnsafeMutableBufferPointer { p in
                arduino_http_server_client_read(p.baseAddress, cap)
            }

            if n <= 0 { break }
            let nn = Int(n)
            if nn > 0 {
                rx.append(contentsOf: tmp[0..<nn])
            }

            if rx.count > (headerMaxBytes + bodyMaxBytes) {
                break
            }
        }
    }

    private func writeResponse(_ resp: HTTPResponse) {
        var out: [U8] = []
        out.reserveCapacity(128 + resp.body.count)

        out += Array("HTTP/1.1 ".utf8)
        out += asciiInt(resp.status)
        out.append(0x20)
        out += statusReason(resp.status)
        out += Array("\r\n".utf8)

        out += Array("Content-Type: ".utf8)
        out += resp.contentType
        out += Array("\r\n".utf8)

        out += Array("Connection: close\r\n".utf8)

        out += Array("Content-Length: ".utf8)
        out += asciiInt(I32(resp.body.count))
        out += Array("\r\n\r\n".utf8)

        out.withUnsafeBufferPointer { p in
            _ = arduino_http_server_client_write(p.baseAddress, U32(out.count))
        }

        if !resp.body.isEmpty {
            resp.body.withUnsafeBufferPointer { p in
                _ = arduino_http_server_client_write(p.baseAddress, U32(resp.body.count))
            }
        }
    }
}

// ============================================================
// Parsing helpers (ASCII/bytes only)
// ============================================================

@inline(__always)
private func statusReason(_ status: I32) -> [U8] {
    switch status {
    case 200: return Array("OK".utf8)
    case 201: return Array("Created".utf8)
    case 204: return Array("No Content".utf8)
    case 400: return Array("Bad Request".utf8)
    case 401: return Array("Unauthorized".utf8)
    case 403: return Array("Forbidden".utf8)
    case 404: return Array("Not Found".utf8)
    case 405: return Array("Method Not Allowed".utf8)
    case 413: return Array("Payload Too Large".utf8)
    case 500: return Array("Internal Server Error".utf8)
    default:  return Array("OK".utf8)
    }
}

@inline(__always)
private func findHeaderEnd(_ bytes: [U8]) -> Int {
    if bytes.count < 4 { return -1 }
    var i = 3
    while i < bytes.count {
        if bytes[i-3] == 13 && bytes[i-2] == 10 && bytes[i-1] == 13 && bytes[i] == 10 {
            return i + 1
        }
        i += 1
    }
    return -1
}

private func parseRequest(_ bytes: [U8], headerEndIndex: Int, bodyLen: Int) -> HTTPRequest? {
    let header = Array(bytes[0..<headerEndIndex])

    guard let lineEnd = findCRLF(header, start: 0) else { return nil }
    let reqLine = Array(header[0..<lineEnd])

    var p = 0
    let mEnd = findByte(reqLine, byte: 0x20, start: p) ?? -1
    if mEnd < 0 { return nil }
    let methodBytes = Array(reqLine[p..<mEnd])
    p = mEnd + 1

    let pathEnd = findByte(reqLine, byte: 0x20, start: p) ?? -1
    if pathEnd < 0 { return nil }
    let pathBytes = Array(reqLine[p..<pathEnd])

    let method: HTTPMethod
    if asciiEqual(methodBytes, Array("GET".utf8)) {
        method = .get
    } else if asciiEqual(methodBytes, Array("POST".utf8)) {
        method = .post
    } else {
        return nil
    }

    var headers: [HTTPHeader] = []
    headers.reserveCapacity(8)

    var cur = lineEnd + 2
    while cur + 2 <= header.count {
        if cur + 1 < header.count, header[cur] == 13, header[cur+1] == 10 { break }

        guard let hEnd = findCRLF(header, start: cur) else { break }
        let line = Array(header[cur..<hEnd])
        cur = hEnd + 2

        guard let colon = findByte(line, byte: 0x3A, start: 0) else { continue }
        let name = rtrimSpaces(Array(line[0..<colon]))
        let value = ltrimSpaces(Array(line[(colon+1)..<line.count]))
        headers.append(.init(name: name, value: value))
    }

    var body: [U8] = []
    if bodyLen > 0 {
        let start = headerEndIndex
        let end = min(bytes.count, start + bodyLen)
        if end > start {
            body = Array(bytes[start..<end])
        }
    }

    return .init(method: method, path: pathBytes, headers: headers, body: body)
}

private func parseContentLength(_ bytes: [U8], headerEndIndex: Int) -> Int? {
    let header = Array(bytes[0..<headerEndIndex])

    guard let firstCRLF = findCRLF(header, start: 0) else { return nil }
    var cur = firstCRLF + 2

    let target = Array("Content-Length".utf8)

    while cur + 2 <= header.count {
        if cur + 1 < header.count, header[cur] == 13, header[cur+1] == 10 { break }

        guard let hEnd = findCRLF(header, start: cur) else { break }
        let line = Array(header[cur..<hEnd])
        cur = hEnd + 2

        guard let colon = findByte(line, byte: 0x3A, start: 0) else { continue }

        let name = rtrimSpaces(Array(line[0..<colon]))
        if !asciiCaseInsensitiveEqual(name, target) { continue }

        let value = ltrimSpaces(Array(line[(colon+1)..<line.count]))
        return asciiParseInt(value)
    }

    return nil
}

@inline(__always)
private func findCRLF(_ bytes: [U8], start: Int) -> Int? {
    var i = start + 1
    while i < bytes.count {
        if bytes[i-1] == 13 && bytes[i] == 10 { return i - 1 }
        i += 1
    }
    return nil
}

@inline(__always)
private func findByte(_ bytes: [U8], byte: U8, start: Int) -> Int? {
    var i = start
    while i < bytes.count {
        if bytes[i] == byte { return i }
        i += 1
    }
    return nil
}

@inline(__always)
private func ltrimSpaces(_ bytes: [U8]) -> [U8] {
    var i = 0
    while i < bytes.count && (bytes[i] == 0x20 || bytes[i] == 0x09) { i += 1 }
    if i == 0 { return bytes }
    return Array(bytes[i..<bytes.count])
}

@inline(__always)
private func rtrimSpaces(_ bytes: [U8]) -> [U8] {
    if bytes.isEmpty { return bytes }
    var j = bytes.count - 1
    while true {
        let b = bytes[j]
        if b != 0x20 && b != 0x09 { break }
        if j == 0 { return [] }
        j -= 1
    }
    return Array(bytes[0...j])
}

@inline(__always)
private func asciiEqual(_ a: [U8], _ b: [U8]) -> Bool {
    if a.count != b.count { return false }
    var i = 0
    while i < a.count {
        if a[i] != b[i] { return false }
        i += 1
    }
    return true
}

@inline(__always)
private func asciiCaseInsensitiveEqual(_ a: [U8], _ b: [U8]) -> Bool {
    if a.count != b.count { return false }
    var i = 0
    while i < a.count {
        if asciiLower(a[i]) != asciiLower(b[i]) { return false }
        i += 1
    }
    return true
}

@inline(__always)
private func asciiLower(_ b: U8) -> U8 {
    if b >= 0x41 && b <= 0x5A { return b &+ 0x20 }
    return b
}

@inline(__always)
private func asciiParseInt(_ bytes: [U8]) -> Int? {
    var i = 0
    while i < bytes.count && (bytes[i] == 0x20 || bytes[i] == 0x09) { i += 1 }
    if i >= bytes.count { return nil }

    var sign = 1
    if bytes[i] == 0x2D { sign = -1; i += 1 }

    var val = 0
    var any = false
    while i < bytes.count {
        let b = bytes[i]
        if b < 0x30 || b > 0x39 { break }
        any = true
        val = val * 10 + Int(b - 0x30)
        i += 1
    }
    return any ? (val * sign) : nil
}

@inline(__always)
private func asciiInt(_ v: I32) -> [U8] {
    var n = v
    if n == 0 { return [0x30] }

    var out: [U8] = []
    if n < 0 { out.append(0x2D); n = -n }

    var tmp: [U8] = []
    while n > 0 {
        let d = U8(n % 10)
        tmp.append(0x30 &+ d)
        n /= 10
    }

    var i = tmp.count
    while i > 0 {
        i -= 1
        out.append(tmp[i])
    }

    return out
}

@inline(__always)
private func asciiString(_ bytes: [U8]) -> String {
    var buf = [CChar](repeating: 0, count: bytes.count + 1)
    var i = 0
    while i < bytes.count {
        buf[i] = CChar(bitPattern: bytes[i])
        i += 1
    }
    return String(cString: buf)
}

@inline(__always)
private func staticUTF8(_ s: StaticString) -> [U8] {
    let utf8 = s.utf8Start
    let len = s.utf8CodeUnitCount
    var out: [U8] = []
    out.reserveCapacity(len)
    var i = 0
    while i < len {
        out.append(U8(utf8[i]))
        i += 1
    }
    return out
}