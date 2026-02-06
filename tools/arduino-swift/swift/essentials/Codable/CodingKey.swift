public protocol CodingKey: Sendable {
    var stringValue: String { get }
    init?(stringValue: String)

    var intValue: Int? { get }
    init?(intValue: Int)
}

public extension CodingKey {
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
}
