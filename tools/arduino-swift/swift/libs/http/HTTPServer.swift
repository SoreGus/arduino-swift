// ============================================================
// ArduinoSwift - HTTP Server (tick-based)
// File: swift/libs/http/HTTPServer.swift
//
// Minimal embedded HTTP/1.1 server over TCPServer/TCPClient.
// - Accepts at most 1 client per tick
// - Reads header until CRLFCRLF (bounded)
// - Reads body by Content-Length (bounded)
// - Exact route match on method + path (no regex)
//
// Requires (project types):
// - ArduinoTickable
// - TCPServer/TCPClient from socket lib
// - HTTPRequest / HTTPResponse / HTTPMethod
// - HTTPBytes / HTTPParsers
// ============================================================

public final class HTTPServer: ArduinoTickable {

    public typealias Handler = (HTTPRequest) -> HTTPResponse

    private struct Route {
        let method: HTTPMethod
        let path: [U8]
        let handler: Handler
    }

    private let port: UInt16
    private let maxHeadBytes: Int
    private let maxBodyBytes: Int

    private var server: TCPServer?
    private var started: Bool = false
    private var routes: [Route] = []

    private var onErrorBlock: ((String) -> Void)?

    public init(port: UInt16, maxHeadBytes: Int = 1024, maxBodyBytes: Int = 2048) {
        self.port = port
        self.maxHeadBytes = maxHeadBytes
        self.maxBodyBytes = maxBodyBytes
        // Start explicitly via begin()
        self.server = nil
        print("Checkpoint 4\n")
    }

    // MARK: - Public API

    @discardableResult
    public func begin() -> Bool {
        print("Checkpoint 3\n")
        if started { return true }
        if server == nil { server = TCPServer(port: port) }
        started = server?.begin() ?? false
        if !started { reportError("HTTPServer.begin failed") }
        return started
    }

    @discardableResult
    public func get(_ path: String, _ handler: @escaping Handler) -> Self {
        routes.append(Route(method: .get, path: Array(path.utf8), handler: handler))
        return self
    }

    @discardableResult
    public func post(_ path: String, _ handler: @escaping Handler) -> Self {
        routes.append(Route(method: .post, path: Array(path.utf8), handler: handler))
        return self
    }

    @discardableResult
    public func onError(_ cb: @escaping (String) -> Void) -> Self {
        self.onErrorBlock = cb
        return self
    }

    // MARK: - ArduinoTickable

    public func tick() {
        print("Checkpoint 5\n")
        guard started, let s = server else { return }
        guard let c = s.accept() else { return }
        handleClient(c)
        c.close()
    }

    // MARK: - Client handling

    private func handleClient(_ c: TCPClient) {
        // --- Read head until CRLFCRLF ---
        var head: [U8] = []
        head.reserveCapacity(256)

        var foundEnd = false
        while head.count < maxHeadBytes {
            var one: [U8] = [0]
            let r = one.withUnsafeMutableBufferPointer { mbuf -> Int in
                guard let base = mbuf.baseAddress else { return 0 }
                return c.read(into: base, max: 1)
            }
            if r <= 0 { break }
            head.append(one[0])

            let n = head.count
            if n >= 4,
               head[n - 4] == 13, head[n - 3] == 10,
               head[n - 2] == 13, head[n - 1] == 10 {
                foundEnd = true
                break
            }
        }

        if !foundEnd {
            _ = send(c, HTTPResponse.badRequest("Header not complete"))
            return
        }

        guard let parsed = HTTPParsers.parseRequestHead(head) else {
            _ = send(c, HTTPResponse.badRequest("Invalid request"))
            return
        }

        let cl = parsed.contentLength
        if cl > maxBodyBytes {
            _ = send(c, HTTPResponse.status(413, "text/plain", "Payload Too Large"))
            return
        }

        // --- Read body by Content-Length ---
        var body: [U8] = []
        if cl > 0 {
            body.reserveCapacity(cl)
            while body.count < cl {
                var one: [U8] = [0]
                let r = one.withUnsafeMutableBufferPointer { mbuf -> Int in
                    guard let base = mbuf.baseAddress else { return 0 }
                    return c.read(into: base, max: 1)
                }
                if r <= 0 { break }
                body.append(one[0])
            }
            if body.count < cl {
                _ = send(c, HTTPResponse.badRequest("Body incomplete"))
                return
            }
        }

        let req = HTTPRequest(
            method: parsed.method,
            pathBytes: parsed.pathBytes,
            queryBytes: parsed.queryBytes,
            headers: parsed.headers,
            body: body
        )

        let resp = route(req) ?? HTTPResponse.notFound()
        _ = send(c, resp)
    }

    private func route(_ req: HTTPRequest) -> HTTPResponse? {
        for r in routes {
            if r.method == req.method && HTTPBytes.eq(r.path, req.pathBytes) {
                return r.handler(req)
            }
        }
        return nil
    }

    // MARK: - Send response

    private func send(_ c: TCPClient, _ resp: HTTPResponse) -> Bool {
        var out: [U8] = []
        out.reserveCapacity(128 + resp.body.count)

        // Status line
        out.append(contentsOf: HTTPBytes.ascii("HTTP/1.1 "))
        out.append(contentsOf: HTTPParsers.intToASCII(resp.status))
        out.append(32)
        out.append(contentsOf: HTTPBytes.ascii(resp.reasonPhrase))
        out.append(contentsOf: HTTPBytes.ascii("\r\n"))

        // Content-Type (resp.contentType is already [U8])
        out.append(contentsOf: HTTPBytes.ascii("Content-Type: "))
        out.append(contentsOf: resp.contentType)
        out.append(contentsOf: HTTPBytes.ascii("\r\n"))

        // Content-Length
        out.append(contentsOf: HTTPBytes.ascii("Content-Length: "))
        out.append(contentsOf: HTTPParsers.intToASCII(resp.body.count))
        out.append(contentsOf: HTTPBytes.ascii("\r\n"))

        // Connection + end of headers
        out.append(contentsOf: HTTPBytes.ascii("Connection: close\r\n\r\n"))

        // Body
        out.append(contentsOf: resp.body)

        let w = c.write(out)
        if w <= 0 {
            reportError("HTTPServer: TCP write failed")
            return false
        }
        return true
    }

    // MARK: - Error

    @inline(__always)
    private func reportError(_ msg: String) {
        onErrorBlock?(msg)
    }
}