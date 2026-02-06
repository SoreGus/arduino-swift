public struct URL: Equatable, Sendable {
    public let absoluteString: String

    public init?(_ string: String) {
        guard !string.isEmpty else { return nil }
        self.absoluteString = string
    }

    public init?(components: URLComponents) {
        guard let s = components.string else { return nil }
        self.absoluteString = s
    }
}
