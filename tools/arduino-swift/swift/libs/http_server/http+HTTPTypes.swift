// http+HTTPTypes.swift
// HTTP request/response types (embedded-safe, no Foundation)

public enum HTTPMethod: U8, Sendable {
    case get  = 1
    case post = 2
}

public struct HTTPHeader: Sendable {
    public let name: [U8]
    public let value: [U8]

    public init(name: [U8], value: [U8]) {
        self.name = name
        self.value = value
    }
}

public struct HTTPRequest: Sendable {
    public let method: HTTPMethod
    public let path: [U8]
    public let headers: [HTTPHeader]
    public let body: [U8]

    public init(method: HTTPMethod, path: [U8], headers: [HTTPHeader], body: [U8]) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }

    public func pathString() -> String { ASCII.stringFromBytes(path) }

    public func header(_ name: StaticString) -> [U8]? {
        let n = ASCII.staticUTF8(name)
        for h in headers {
            if ASCII.caseInsensitiveEqual(h.name, n) { return h.value }
        }
        return nil
    }

    public func contentLength() -> Int {
        if let v = header("Content-Length") {
            return ASCII.parseInt(v) ?? 0
        }
        return 0
    }
}

public extension HTTPRequest {
    func isJSON() -> Bool {
        guard let ct = header("Content-Type") else { return false }
        return ASCII.hasPrefixCaseInsensitive(ct, Array("application/json".utf8))
    }

    func jsonBody() -> EssentialsJSONValue? {
        guard isJSON() else { return nil }
        let (v, e) = JSONSerialization().jsonObject(with: Data(body))
        return e == .none ? v : nil
    }
}

public struct HTTPResponse: Sendable {
    public let status: I32
    public let contentType: [U8]
    public let body: [U8]

    public init(status: I32, contentType: [U8], body: [U8]) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

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

    public static func json(_ v: EssentialsJSONValue, status: I32 = 200) -> HTTPResponse {
        .init(
            status: status,
            contentType: Array("application/json; charset=utf-8".utf8),
            body: JSONSerialization.data(from: v).toArray()
        )
    }
}
