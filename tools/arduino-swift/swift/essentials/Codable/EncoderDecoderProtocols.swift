public protocol Encoder {
    var codingPath: [any CodingKey] { get }
    var userInfo: [String: Any] { get }

    func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey
    func unkeyedContainer() -> UnkeyedEncodingContainer
    func singleValueContainer() -> SingleValueEncodingContainer
}

public protocol Decoder {
    var codingPath: [any CodingKey] { get }
    var userInfo: [String: Any] { get }

    func container<Key>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey
    func unkeyedContainer() throws -> UnkeyedDecodingContainer
    func singleValueContainer() throws -> SingleValueDecodingContainer
}
