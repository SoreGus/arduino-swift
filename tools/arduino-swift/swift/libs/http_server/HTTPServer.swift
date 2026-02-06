//
//  HTTPServer.swift
//  ArduinoSwift - Minimal HTTP Server (UNO R4 WiFi)
//
//  Minimal HTTP/1.1 server (tick-based) for Embedded Swift (no Foundation)
//
//  Supports 2 styles of handlers:
//    1) Sync:  (HTTPRequest) -> HTTPResponse
//    2) Async: (HTTPRequest, @escaping (HTTPResponse) -> Void) -> Void
//
//  Async design notes:
//  - One request per connection, Connection: close
//  - While async is pending, new requests are not processed
//  - Async callback only stores pending response; write/close happens in tick()
//

public final class HTTPServer: ArduinoTickable {

    // MARK: - Public types

    public typealias SyncHandler = (HTTPRequest) -> HTTPResponse
    public typealias AsyncHandler = (HTTPRequest, @escaping (HTTPResponse) -> Void) -> Void
    public typealias FailureHandler = (HTTPServerError) -> Void

    public enum RouteHandler {
        case sync(SyncHandler)
        case async(AsyncHandler)
    }

    public struct Route {
        public let method: HTTPMethod
        public let path: [U8]
        public let handler: RouteHandler

        public init(method: HTTPMethod, path: [U8], handler: RouteHandler) {
            self.method = method
            self.path = path
            self.handler = handler
        }
    }

    public struct HTTPServerError {
        public let message: String
        public init(_ message: String) { self.message = message }
    }

    public struct Limits: Sendable {
        public var headerMaxBytes: Int
        public var bodyMaxBytes: Int
        public var bodyWaitMs: U32
        public var asyncWaitMs: U32
        public var pollMs: U32

        public init(
            headerMaxBytes: Int = 2048,
            bodyMaxBytes: Int = 2048,
            bodyWaitMs: U32 = 8000,
            asyncWaitMs: U32 = 8000,
            pollMs: U32 = 5
        ) {
            self.headerMaxBytes = headerMaxBytes
            self.bodyMaxBytes = bodyMaxBytes
            self.bodyWaitMs = bodyWaitMs
            self.asyncWaitMs = asyncWaitMs
            self.pollMs = pollMs
        }
    }

    // MARK: - Private state

    private var routes: [Route] = []
    private var failure: FailureHandler?

    private var port: UInt16 = 80
    private var running: Bool = false

    private var rx: [U8] = []
    private var headerEndIndex: Int = -1
    private var expectedBodyLen: Int = 0

    // configurable
    private var headerMaxBytes: Int = 2048
    private var bodyMaxBytes: Int = 2048
    private var bodyWaitMs: U32 = 8000
    private var pollMs: U32 = 5
    private var asyncWaitMs: U32 = 8000

    private var nextPollAt: U32 = 0
    private var bodyWaitStart: U32 = 0

    // Async pending response
    private var pendingAsync: Bool = false
    private var pendingAsyncStartedAt: U32 = 0
    private var pendingResponse: HTTPResponse? = nil

    public init() {}

    // MARK: - Public API

    public func configure(_ limits: Limits) {
        headerMaxBytes = limits.headerMaxBytes < 256 ? 256 : limits.headerMaxBytes
        bodyMaxBytes = limits.bodyMaxBytes < 0 ? 0 : limits.bodyMaxBytes
        bodyWaitMs = limits.bodyWaitMs == 0 ? 1 : limits.bodyWaitMs
        asyncWaitMs = limits.asyncWaitMs == 0 ? 1 : limits.asyncWaitMs
        pollMs = limits.pollMs == 0 ? 1 : limits.pollMs
    }

    public func onFailure(_ cb: @escaping FailureHandler) {
        self.failure = cb
    }

    // Sync routes
    public func get(_ path: String, _ handler: @escaping SyncHandler) {
        routes.append(.init(method: .get, path: Array(path.utf8), handler: .sync(handler)))
    }

    public func post(_ path: String, _ handler: @escaping SyncHandler) {
        routes.append(.init(method: .post, path: Array(path.utf8), handler: .sync(handler)))
    }

    // Async routes
    public func get(_ path: String, _ handler: @escaping AsyncHandler) {
        routes.append(.init(method: .get, path: Array(path.utf8), handler: .async(handler)))
    }

    public func post(_ path: String, _ handler: @escaping AsyncHandler) {
        routes.append(.init(method: .post, path: Array(path.utf8), handler: .async(handler)))
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
        resetPending()
        return true
    }

    public func stop() {
        arduino_http_server_end()
        running = false
        resetRx()
        resetPending()
    }

    public func addToRuntime() {
        ArduinoRuntime.add(self)
    }

    // MARK: - Tick

    public func tick() {
        if !running { return }

        let now = arduino_millis()
        if now < nextPollAt { return }
        nextPollAt = now &+ pollMs

        // 1) Waiting async completion
        if pendingAsync {
            if let resp = pendingResponse {
                writeResponse(resp)
                arduino_http_server_client_stop()
                resetRx()
                resetPending()
                return
            }

            if (now &- pendingAsyncStartedAt) > asyncWaitMs {
                failure?(.init("Async response timeout"))
                writeResponse(.response("Async timeout\n", status: 504, contentType: "text/plain; charset=utf-8"))
                arduino_http_server_client_stop()
                resetRx()
                resetPending()
            }
            return
        }

        // 2) Normal flow
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

        guard let match = findRoute(req) else {
            writeResponse(.response("Not Found\n", status: 404, contentType: "text/plain; charset=utf-8"))
            arduino_http_server_client_stop()
            resetRx()
            return
        }

        switch match.handler {
        case .sync(let h):
            let resp = h(req)
            writeResponse(resp)
            arduino_http_server_client_stop()
            resetRx()

        case .async(let h):
            pendingAsync = true
            pendingAsyncStartedAt = arduino_millis()
            pendingResponse = nil

            // optional: free request buffer memory while waiting
            resetRx()

            h(req) { resp in
                // IMPORTANT:
                // do not write/close here; only store response
                self.pendingResponse = resp
            }
        }
    }

    // MARK: - Internals

    private func resetRx() {
        rx.removeAll(keepingCapacity: true)
        headerEndIndex = -1
        expectedBodyLen = 0
        bodyWaitStart = 0
    }

    private func resetPending() {
        pendingAsync = false
        pendingAsyncStartedAt = 0
        pendingResponse = nil
    }

    private func failAndClose(_ msg: String) {
        failure?(.init(msg))
        arduino_http_server_client_stop()
        resetRx()
        resetPending()
    }

    private func findRoute(_ req: HTTPRequest) -> Route? {
        for r in routes {
            if r.method == req.method && r.path == req.path {
                return r
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
        out += ASCII.intToBytes(resp.status)
        out.append(0x20)
        out += statusReason(resp.status)
        out += Array("\r\n".utf8)

        out += Array("Content-Type: ".utf8)
        out += resp.contentType
        out += Array("\r\n".utf8)

        out += Array("Connection: close\r\n".utf8)

        out += Array("Content-Length: ".utf8)
        out += ASCII.intToBytes(I32(resp.body.count))
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
// HTTP parsing helpers (file-private)
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
    case 504: return Array("Gateway Timeout".utf8)
    default:  return Array("OK".utf8)
    }
}

@inline(__always)
private func findHeaderEnd(_ bytes: [U8]) -> Int {
    if bytes.count < 4 { return -1 }
    var i = 3
    while i < bytes.count {
        if bytes[i - 3] == 13 && bytes[i - 2] == 10 && bytes[i - 1] == 13 && bytes[i] == 10 {
            return i + 1
        }
        i += 1
    }
    return -1
}

private func parseRequest(_ bytes: [U8], headerEndIndex: Int, bodyLen: Int) -> HTTPRequest? {
    let header = Array(bytes[0..<headerEndIndex])

    guard let lineEnd = ASCII.findCRLF(header, start: 0) else { return nil }
    let reqLine = Array(header[0..<lineEnd])

    var p = 0
    let mEnd = ASCII.findByte(reqLine, byte: 0x20, start: p) ?? -1
    if mEnd < 0 { return nil }
    let methodBytes = Array(reqLine[p..<mEnd])
    p = mEnd + 1

    let pathEnd = ASCII.findByte(reqLine, byte: 0x20, start: p) ?? -1
    if pathEnd < 0 { return nil }
    let pathBytes = Array(reqLine[p..<pathEnd])

    let method: HTTPMethod
    if ASCII.equal(methodBytes, Array("GET".utf8)) {
        method = .get
    } else if ASCII.equal(methodBytes, Array("POST".utf8)) {
        method = .post
    } else {
        return nil
    }

    var headers: [HTTPHeader] = []
    headers.reserveCapacity(8)

    var cur = lineEnd + 2
    while cur + 2 <= header.count {
        if cur + 1 < header.count, header[cur] == 13, header[cur + 1] == 10 { break }

        guard let hEnd = ASCII.findCRLF(header, start: cur) else { break }
        let line = Array(header[cur..<hEnd])
        cur = hEnd + 2

        guard let colon = ASCII.findByte(line, byte: 0x3A, start: 0) else { continue }
        let name = ASCII.rtrimSpaces(Array(line[0..<colon]))
        let value = ASCII.ltrimSpaces(Array(line[(colon + 1)..<line.count]))
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

    guard let firstCRLF = ASCII.findCRLF(header, start: 0) else { return nil }
    var cur = firstCRLF + 2

    let target = Array("Content-Length".utf8)

    while cur + 2 <= header.count {
        if cur + 1 < header.count, header[cur] == 13, header[cur + 1] == 10 { break }

        guard let hEnd = ASCII.findCRLF(header, start: cur) else { break }
        let line = Array(header[cur..<hEnd])
        cur = hEnd + 2

        guard let colon = ASCII.findByte(line, byte: 0x3A, start: 0) else { continue }

        let name = ASCII.rtrimSpaces(Array(line[0..<colon]))
        if !ASCII.caseInsensitiveEqual(name, target) { continue }

        let value = ASCII.ltrimSpaces(Array(line[(colon + 1)..<line.count]))
        return ASCII.parseInt(value)
    }

    return nil
}