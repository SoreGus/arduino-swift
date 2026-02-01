// http+HTTPTypes.swift
// HTTP request/response types (no Foundation)

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

    public func pathString() -> String { ASCII.stringFromBytes(path) }

    /// Case-insensitive ASCII header lookup (e.g. "Content-Length", "Content-Type")
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

// ============================================================
// Request JSON helpers (no Foundation)
// ============================================================

public extension HTTPRequest {

    /// True when Content-Type begins with "application/json" (case-insensitive),
    /// accepting suffixes like "; charset=utf-8".
    func isJSON() -> Bool {
        guard let ct = header("Content-Type") else { return false }
        return ASCII.hasPrefixCaseInsensitive(ct, Array("application/json".utf8))
    }

    /// Parse the request body as JSON only if Content-Type is application/json.
    func jsonBody() -> JSONValue? {
        guard isJSON() else { return nil }
        return JSONParser.parse(body)
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