// ============================================================
// ArduinoSwift - HTTP Types
// File: swift/libs/http/HTTPTypes.swift
// ============================================================

public enum HTTPMethod: UInt8, Sendable, Equatable {
    case get, post, put, delete, head, options, patch

    public static func parse(_ bytes: ArraySlice<U8>) -> HTTPMethod? {
        let tmp = Array(bytes)
        if HTTPBytes.eq(tmp, HTTPBytes.ascii("GET")) { return .get }
        if HTTPBytes.eq(tmp, HTTPBytes.ascii("POST")) { return .post }
        if HTTPBytes.eq(tmp, HTTPBytes.ascii("PUT")) { return .put }
        if HTTPBytes.eq(tmp, HTTPBytes.ascii("DELETE")) { return .delete }
        if HTTPBytes.eq(tmp, HTTPBytes.ascii("HEAD")) { return .head }
        if HTTPBytes.eq(tmp, HTTPBytes.ascii("OPTIONS")) { return .options }
        if HTTPBytes.eq(tmp, HTTPBytes.ascii("PATCH")) { return .patch }
        return nil
    }

    public var bytesUpper: [U8] {
        switch self {
        case .get: return HTTPBytes.ascii("GET")
        case .post: return HTTPBytes.ascii("POST")
        case .put: return HTTPBytes.ascii("PUT")
        case .delete: return HTTPBytes.ascii("DELETE")
        case .head: return HTTPBytes.ascii("HEAD")
        case .options: return HTTPBytes.ascii("OPTIONS")
        case .patch: return HTTPBytes.ascii("PATCH")
        }
    }
}

public struct HTTPHeader: Sendable, Equatable {
    public let nameLower: [U8]
    public let value: [U8]
    public init(nameLower: [U8], value: [U8]) {
        self.nameLower = nameLower
        self.value = value
    }
}

public struct HTTPRequest: Sendable {
    public let method: HTTPMethod
    public let pathBytes: [U8]
    public let queryBytes: [U8]
    public let headers: [HTTPHeader]
    public let body: [U8]

    public var path: String { HTTPBytes.toString(pathBytes) }
    public var query: String { HTTPBytes.toString(queryBytes) }
    public var bodyString: String { HTTPBytes.toString(body) }
}

public struct HTTPResponse: Sendable {
    public let status: Int
    public let contentType: [U8]
    public let body: [U8]

    public init(status: Int, contentType: [U8], body: [U8]) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

    public var reasonPhrase: String {
        switch status {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 413: return "Payload Too Large"
        case 500: return "Internal Server Error"
        default:  return "OK"
        }
    }

    public static func status(_ code: Int, _ contentType: String, _ body: String) -> HTTPResponse {
        HTTPResponse(status: code, contentType: HTTPBytes.ascii(contentType), body: HTTPBytes.ascii(body))
    }

    public static func okText(_ s: String) -> HTTPResponse { .status(200, "text/plain", s) }
    public static func badRequest(_ s: String) -> HTTPResponse { .status(400, "text/plain", s) }
    public static func notFound() -> HTTPResponse { .status(404, "text/plain", "Not Found") }
}

public struct HTTPClientResponse: Sendable {
    public let status: Int
    public let contentType: [U8]
    public let headers: [HTTPHeader]
    public let body: [U8]
}