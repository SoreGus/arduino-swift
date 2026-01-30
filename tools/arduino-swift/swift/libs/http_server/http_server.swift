// http_server.swift
// ArduinoSwift - HTTP server (UNO R4 WiFi) - ASCII/bytes only (Embedded Swift friendly)

public enum HTTPMethod: U8, Sendable {
    case GET  = 1
    case POST = 2
    case PUT  = 3
    case DELETE = 4
    case PATCH  = 5
    case HEAD   = 6
    case OPTIONS = 7

    static func fromBytes(_ b: [U8]) -> HTTPMethod? {
        if b.count == 3, b[0] == 0x47, b[1] == 0x45, b[2] == 0x54 { return .GET }
        if b.count == 4, b[0] == 0x50, b[1] == 0x4F, b[2] == 0x53, b[3] == 0x54 { return .POST }
        if b.count == 3, b[0] == 0x50, b[1] == 0x55, b[2] == 0x54 { return .PUT }
        if b.count == 6,
           b[0] == 0x44, b[1] == 0x45, b[2] == 0x4C, b[3] == 0x45, b[4] == 0x54, b[5] == 0x45 { return .DELETE }
        if b.count == 5,
           b[0] == 0x50, b[1] == 0x41, b[2] == 0x54, b[3] == 0x43, b[4] == 0x48 { return .PATCH }
        if b.count == 4,
           b[0] == 0x48, b[1] == 0x45, b[2] == 0x41, b[3] == 0x44 { return .HEAD }
        if b.count == 7,
           b[0] == 0x4F, b[1] == 0x50, b[2] == 0x54, b[3] == 0x49, b[4] == 0x4F, b[5] == 0x4E, b[6] == 0x53 { return .OPTIONS }
        return nil
    }
}

public struct HTTPRequest: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let body: [U8]
    public init(method: HTTPMethod, path: String, body: [U8]) {
        self.method = method
        self.path = path
        self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public let status: I32
    public let contentType: String
    public let body: [U8]

    public init(status: I32, contentType: String, body: [U8]) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

    public static func text(_ s: String, status: I32 = 200, contentType: String = "text/plain; charset=utf-8") -> HTTPResponse {
        let bytes = Array(s.utf8).map { U8($0) }
        return .init(status: status, contentType: contentType, body: bytes)
    }

    public static func data(_ bytes: [U8], status: I32 = 200, contentType: String = "application/octet-stream") -> HTTPResponse {
        .init(status: status, contentType: contentType, body: bytes)
    }
}

public struct HTTPServerError: Sendable {
    public let code: I32
    public let message: String
    public init(code: I32, message: String) { self.code = code; self.message = message }
}

public final class HTTPServer: ArduinoTickable {

    public typealias Handler = (HTTPRequest) -> HTTPResponse
    public typealias Failure = (HTTPServerError) -> Void

    private struct Route {
        let method: HTTPMethod
        let pathBytes: [U8]
        let handler: Handler
    }

    private var routes: [Route] = []
    private var failure: Failure?

    private var running: Bool = false
    private var port: UInt16 = 80

    private var rx: [U8] = []

    private let headerMaxBytes: Int = 1024
    private let bodyMaxBytes: Int = 1024

    public init() {}

    // (opcional) se você quiser mesmo esse helper
    public func addToRuntime() { ArduinoRuntime.add(self) }

    public func onFailure(_ f: @escaping Failure) { self.failure = f }

    public func get(_ path: String, _ h: @escaping Handler) { addRoute(.GET, path, h) }
    public func post(_ path: String, _ h: @escaping Handler) { addRoute(.POST, path, h) }
    public func put(_ path: String, _ h: @escaping Handler) { addRoute(.PUT, path, h) }
    public func delete(_ path: String, _ h: @escaping Handler) { addRoute(.DELETE, path, h) }

    @discardableResult
    public func start(port: UInt16 = 80) -> Bool {
        self.port = port
        let rc = arduino_http_server_begin(port)
        if rc != 1 {
            fail(code: rc, msg: "arduino_http_server_begin failed")
            running = false
            return false
        }
        running = true
        return true
    }

    public func stop() {
        running = false
        arduino_http_server_end()
    }

    public func tick() {
        if !running { return }
        if arduino_http_server_client_available() != 1 { return }

        rx.removeAll(keepingCapacity: true)

        if !readUntilHeaderEnd(maxBytes: headerMaxBytes) {
            arduino_http_server_client_stop()
            return
        }

        guard let (method, pathBytes, contentLength) = parseHeader(rx) else {
            sendSimple(status: 400, contentType: "text/plain; charset=utf-8", body: asciiBytes("Bad Request\n"))
            arduino_http_server_client_stop()
            return
        }

        var body: [U8] = []
        if contentLength > 0 {
            let toRead = min(contentLength, bodyMaxBytes)
            body = readBody(exactly: toRead)
        }

        let path = asciiString(pathBytes)
        let req = HTTPRequest(method: method, path: path, body: body)

        if let h = matchRoute(method: method, pathBytes: pathBytes) {
            let resp = h(req)
            send(resp)
        } else {
            sendSimple(status: 404, contentType: "text/plain; charset=utf-8", body: asciiBytes("Not Found\n"))
        }

        arduino_http_server_client_stop()
    }

    // ------- routes -------
    private func addRoute(_ method: HTTPMethod, _ path: String, _ h: @escaping Handler) {
        routes.append(Route(method: method, pathBytes: asciiBytes(path), handler: h))
    }

    private func matchRoute(method: HTTPMethod, pathBytes: [U8]) -> Handler? {
        for r in routes {
            if r.method != method { continue }
            if bytesEqual(r.pathBytes, pathBytes) { return r.handler }
        }
        return nil
    }

    // ------- IO -------
    private func readIntoRX(maxBytes: Int) {
        if maxBytes <= 0 { return }
        var tmp = [U8](repeating: 0, count: maxBytes)
        let cap = U32(tmp.count)

        let n: I32 = tmp.withUnsafeMutableBufferPointer { p in
            arduino_http_server_client_read(p.baseAddress, cap)
        }
        if n > 0 {
            rx.append(contentsOf: tmp[0..<Int(n)])
        }
    }

    private func readUntilHeaderEnd(maxBytes: Int) -> Bool {
        while rx.count < maxBytes {
            if arduino_http_server_client_connected() != 1 { return false }
            readIntoRX(maxBytes: 64)
            if rx.count >= 4, findHeaderEnd(rx) != -1 { return true }
        }
        return false
    }

    private func readBody(exactly n: Int) -> [U8] {
        var out: [U8] = []
        out.reserveCapacity(n)

        while out.count < n {
            if arduino_http_server_client_connected() != 1 { break }
            let need = n - out.count
            var tmp = [U8](repeating: 0, count: min(64, need))
            let cap = U32(tmp.count)

            let got: I32 = tmp.withUnsafeMutableBufferPointer { p in
                arduino_http_server_client_read(p.baseAddress, cap)
            }
            if got > 0 {
                out.append(contentsOf: tmp[0..<Int(got)])
            }
        }
        return out
    }

    private func send(_ resp: HTTPResponse) {
        var head: [U8] = []
        head.reserveCapacity(128)

        head += asciiBytes("HTTP/1.1 ")
        head += asciiBytes(statusLine(resp.status))
        head += asciiBytes("\r\nContent-Type: ")
        head += asciiBytes(resp.contentType)
        head += asciiBytes("\r\nContent-Length: ")
        head += asciiBytes(intToASCII(resp.body.count))
        head += asciiBytes("\r\nConnection: close\r\n\r\n")

        _ = writeBytes(head)
        _ = writeBytes(resp.body)
    }

    private func sendSimple(status: I32, contentType: String, body: [U8]) {
        send(HTTPResponse(status: status, contentType: contentType, body: body))
    }

    @discardableResult
    private func writeBytes(_ bytes: [U8]) -> Bool {
        if bytes.isEmpty { return true }
        let n: I32 = bytes.withUnsafeBufferPointer { p in
            arduino_http_server_client_write(p.baseAddress, U32(bytes.count))
        }
        return n == I32(bytes.count)
    }

    // ------- parsing -------
    private func parseHeader(_ buf: [U8]) -> (HTTPMethod, [U8], Int)? {
        let end = findHeaderEnd(buf)
        if end < 0 { return nil }

        var i = 0
        let m0 = i
        while i < end, buf[i] != 0x20 { i += 1 }
        if i == m0 { return nil }
        let methodBytes = Array(buf[m0..<i])
        guard let method = HTTPMethod.fromBytes(methodBytes) else { return nil }
        i += 1

        let p0 = i
        while i < end, buf[i] != 0x20 { i += 1 }
        if i == p0 { return nil }
        var pathBytes = Array(buf[p0..<i])

        if let q = indexOfByte(pathBytes, 0x3F) {
            pathBytes = Array(pathBytes[0..<q])
        }

        let cl = parseContentLength(buf, headerEndIndex: end)
        return (method, pathBytes, cl)
    }

    private func parseContentLength(_ buf: [U8], headerEndIndex: Int) -> Int {
        var i = 0
        while i + 1 < headerEndIndex {
            if buf[i] == 0x0D, buf[i+1] == 0x0A { i += 2; break }
            i += 1
        }

        while i + 1 < headerEndIndex {
            if buf[i] == 0x0D, buf[i+1] == 0x0A { break }

            var j = i
            while j < headerEndIndex, buf[j] != 0x3A,
                  !(buf[j] == 0x0D && j+1 < headerEndIndex && buf[j+1] == 0x0A) {
                j += 1
            }
            if j < headerEndIndex, buf[j] == 0x3A {
                if asciiKeyEquals(buf, i, j, "content-length") {
                    var k = j + 1
                    while k < headerEndIndex, buf[k] == 0x20 { k += 1 }
                    var value = 0
                    while k < headerEndIndex {
                        let c = buf[k]
                        if c >= 0x30 && c <= 0x39 {
                            value = value * 10 + Int(c - 0x30)
                            k += 1
                        } else { break }
                    }
                    return value
                }
            }

            while i + 1 < headerEndIndex {
                if buf[i] == 0x0D, buf[i+1] == 0x0A { i += 2; break }
                i += 1
            }
        }
        return 0
    }

    private func findHeaderEnd(_ buf: [U8]) -> Int {
        if buf.count < 4 { return -1 }
        var i = 0
        while i + 3 < buf.count {
            if buf[i] == 0x0D, buf[i+1] == 0x0A, buf[i+2] == 0x0D, buf[i+3] == 0x0A {
                return i
            }
            i += 1
        }
        return -1
    }

    // ------- utils -------
    private func fail(code: I32, msg: String) { failure?(HTTPServerError(code: code, message: msg)) }

    private func statusLine(_ status: I32) -> String {
        switch status {
        case 200: return "200 OK"
        case 400: return "400 Bad Request"
        case 404: return "404 Not Found"
        case 500: return "500 Internal Server Error"
        default:  return "\(status) OK"
        }
    }

    private func bytesEqual(_ a: [U8], _ b: [U8]) -> Bool {
        if a.count != b.count { return false }
        var i = 0
        while i < a.count {
            if a[i] != b[i] { return false }
            i += 1
        }
        return true
    }

    private func indexOfByte(_ a: [U8], _ v: U8) -> Int? {
        var i = 0
        while i < a.count {
            if a[i] == v { return i }
            i += 1
        }
        return nil
    }

    private func asciiLower(_ c: U8) -> U8 {
        if c >= 0x41 && c <= 0x5A { return c &+ 0x20 }
        return c
    }

    private func asciiKeyEquals(_ buf: [U8], _ start: Int, _ end: Int, _ key: StaticString) -> Bool {
        let kb = asciiBytes(key)
        let len = end - start
        if len != kb.count { return false }
        var i = 0
        while i < len {
            if asciiLower(buf[start + i]) != kb[i] { return false }
            i += 1
        }
        return true
    }

    private func asciiBytes(_ s: String) -> [U8] {
        return Array(s.utf8).map { U8($0) }
    }

    private func asciiBytes(_ s: StaticString) -> [U8] {
        var out: [U8] = []
        out.reserveCapacity(s.utf8CodeUnitCount)
        s.withUTF8Buffer { b in
            for x in b { out.append(U8(x)) }
        }
        return out
    }

    private func asciiString(_ bytes: [U8]) -> String {
        var c: [CChar] = bytes.map { CChar(bitPattern: $0) }
        c.append(0)
        return String(cString: c)
    }

    private func intToASCII(_ n: Int) -> String {
        if n == 0 { return "0" }
        var x = n
        var tmp: [U8] = []
        while x > 0 {
            let d = x % 10
            tmp.append(U8(0x30 + d))
            x /= 10
        }
        var out: [CChar] = []
        out.reserveCapacity(tmp.count + 1)
        var i = tmp.count
        while i > 0 {
            i -= 1
            out.append(CChar(bitPattern: tmp[i]))
        }
        out.append(0)
        return String(cString: out)
    }
}