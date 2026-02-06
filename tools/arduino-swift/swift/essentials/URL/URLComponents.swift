public struct URLComponents: Equatable, Sendable {
    public var scheme: String?
    public var host: String?
    public var port: Int?
    public var path: String = ""
    public var queryItems: [URLQueryItem]?

    public init() {}
}
