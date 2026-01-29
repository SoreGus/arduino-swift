// ============================================================
// ArduinoSwift - HTTP Client (tick-based)
// File: swift/libs/http/HTTPClient.swift
//
// Minimal embedded HTTP/1.1 client over TCPClient.
// - Non-blocking state machine
// - Supports GET and POST with Content-Length
// - Reads response header until CRLFCRLF (bounded)
// - Reads response body by Content-Length (bounded)
//
// Requires:
// - ArduinoTickable
// - ArduinoTime.millis()
// - TCPClient from socket lib
// ============================================================

public final class HTTPClient: ArduinoTickable {

    public struct Request: Sendable {
        public let method: HTTPMethod
        public let host: String
        public let port: UInt16
        public let path: String
        public let contentType: String
        public let body: [U8]

        public init(
            method: HTTPMethod,
            host: String,
            port: UInt16 = 80,
            path: String,
            contentType: String = "text/plain",
            body: [U8] = []
        ) {
            self.method = method
            self.host = host
            self.port = port
            self.path = path
            self.contentType = contentType
            self.body = body
        }
    }

    public typealias Completion = (Bool, HTTPClientResponse?) -> Void

    private enum State {
        case idle
        case connecting(deadline: U32)
        case sending(deadline: U32)
        case readingHead(deadline: U32)
        case readingBody(expected: Int, deadline: U32)
        case done
    }

    private var state: State = .idle
    private var client: TCPClient? = nil
    private var completion: Completion? = nil

    private var req: Request? = nil

    private var tx: [U8] = []
    private var txOffset: Int = 0

    private var head: [U8] = []
    private var body: [U8] = []
    private var parsedHead: HTTPParsers.ParsedResponseHead? = nil

    private let maxHeadBytes: Int
    private let maxBodyBytes: Int

    public init(maxHeadBytes: Int = 1024, maxBodyBytes: Int = 4096) {
        self.maxHeadBytes = maxHeadBytes
        self.maxBodyBytes = maxBodyBytes
    }

    public func get(host: String, port: UInt16 = 80, path: String, timeoutMs: U32 = 8_000, onComplete: @escaping Completion) {
        start(Request(method: .get, host: host, port: port, path: path), timeoutMs: timeoutMs, onComplete: onComplete)
    }

    public func post(host: String, port: UInt16 = 80, path: String, contentType: String, body: [U8], timeoutMs: U32 = 8_000, onComplete: @escaping Completion) {
        start(Request(method: .post, host: host, port: port, path: path, contentType: contentType, body: body), timeoutMs: timeoutMs, onComplete: onComplete)
    }

    public func start(_ request: Request, timeoutMs: U32, onComplete: @escaping Completion) {
        self.req = request
        self.completion = onComplete

        self.client = TCPClient()
        self.head.removeAll(keepingCapacity: true)
        self.body.removeAll(keepingCapacity: true)
        self.parsedHead = nil
        self.tx.removeAll(keepingCapacity: true)
        self.txOffset = 0

        let ok = self.client!.connect(host: request.host, port: request.port)
        let now = ArduinoTime.millis()
        if !ok {
            finish(ok: false, resp: nil)
            return
        }

        state = .connecting(deadline: now &+ timeoutMs)
    }

    public func cancel() {
        client?.close()
        client = nil
        completion = nil
        req = nil
        state = .idle
    }

    public func tick() {
        switch state {
        case .idle, .done:
            return

        case .connecting(let deadline):
            guard let c = client else { finish(ok: false, resp: nil); return }
            if c.connected() {
                buildTX()
                let now = ArduinoTime.millis()
                state = .sending(deadline: now &+ 4_000)
                return
            }
            if isPast(deadline) { finish(ok: false, resp: nil); return }

        case .sending(let deadline):
            guard let c = client else { finish(ok: false, resp: nil); return }
            if txOffset < tx.count {
                let wrote = tx.withUnsafeBufferPointer { buf -> Int in
                    guard let base = buf.baseAddress else { return 0 }
                    return c.write(base.advanced(by: txOffset), count: buf.count - txOffset)
                }
                if wrote > 0 { txOffset += wrote }
            }
            if txOffset >= tx.count {
                let now = ArduinoTime.millis()
                state = .readingHead(deadline: now &+ 4_000)
                return
            }
            if isPast(deadline) { finish(ok: false, resp: nil); return }

        case .readingHead(let deadline):
            guard let c = client else { finish(ok: false, resp: nil); return }

            // read a few bytes per tick
            var loops = 0
            while loops < 64, head.count < maxHeadBytes {
                loops += 1
                if c.available() <= 0 { break }
                var one: [U8] = [0]
                let r = one.withUnsafeMutableBufferPointer { mbuf -> Int in
                    guard let base = mbuf.baseAddress else { return 0 }
                    return c.read(into: base, max: 1)
                }
                if r <= 0 { break }
                head.append(one[0])

                let n = head.count
                if n >= 4,
                   head[n-4] == 13, head[n-3] == 10,
                   head[n-2] == 13, head[n-1] == 10 {
                    // parse head
                    guard let ph = HTTPParsers.parseResponseHead(head) else {
                        finish(ok: false, resp: nil); return
                    }
                    parsedHead = ph
                    let expected = min(ph.contentLength, maxBodyBytes)
                    let now = ArduinoTime.millis()
                    state = .readingBody(expected: expected, deadline: now &+ 4_000)
                    return
                }
            }

            if isPast(deadline) { finish(ok: false, resp: nil); return }

        case .readingBody(let expected, let deadline):
            guard let c = client, let ph = parsedHead else { finish(ok: false, resp: nil); return }

            var loops = 0
            while loops < 128, body.count < expected {
                loops += 1
                if c.available() <= 0 { break }
                var one: [U8] = [0]
                let r = one.withUnsafeMutableBufferPointer { mbuf -> Int in
                    guard let base = mbuf.baseAddress else { return 0 }
                    return c.read(into: base, max: 1)
                }
                if r <= 0 { break }
                body.append(one[0])
            }

            if body.count >= expected {
                let resp = HTTPClientResponse(
                    status: ph.status,
                    contentType: ph.contentType ?? [],
                    headers: ph.headers,
                    body: body
                )
                finish(ok: true, resp: resp)
                return
            }

            if isPast(deadline) { finish(ok: false, resp: nil); return }
        }
    }

    private func buildTX() {
        guard let r = req else { return }

        let path = r.path.isEmpty ? "/" : r.path
        var out: [U8] = []
        out.reserveCapacity(256 + r.body.count)

        out.append(contentsOf: r.method.bytesUpper)
        out.append(32)
        out.append(contentsOf: HTTPBytes.ascii(path))
        out.append(contentsOf: HTTPBytes.ascii(" HTTP/1.1\r\n"))

        out.append(contentsOf: HTTPBytes.ascii("Host: "))
        out.append(contentsOf: HTTPBytes.ascii(r.host))
        out.append(contentsOf: HTTPBytes.ascii("\r\n"))

        out.append(contentsOf: HTTPBytes.ascii("Connection: close\r\n"))

        if r.method == .post || !r.body.isEmpty {
            out.append(contentsOf: HTTPBytes.ascii("Content-Type: "))
            out.append(contentsOf: HTTPBytes.ascii(r.contentType))
            out.append(contentsOf: HTTPBytes.ascii("\r\n"))

            out.append(contentsOf: HTTPBytes.ascii("Content-Length: "))
            out.append(contentsOf: HTTPParsers.intToASCII(r.body.count))
            out.append(contentsOf: HTTPBytes.ascii("\r\n"))
        }

        out.append(contentsOf: HTTPBytes.ascii("\r\n"))
        if !r.body.isEmpty { out.append(contentsOf: r.body) }

        self.tx = out
        self.txOffset = 0
    }

    private func finish(ok: Bool, resp: HTTPClientResponse?) {
        client?.close()
        client = nil

        let cb = completion
        completion = nil
        req = nil
        state = .done

        cb?(ok, resp)
    }

    @inline(__always)
    private func isPast(_ deadline: U32) -> Bool {
        let now = ArduinoTime.millis()
        return (now &- deadline) < 0x8000_0000
    }
}