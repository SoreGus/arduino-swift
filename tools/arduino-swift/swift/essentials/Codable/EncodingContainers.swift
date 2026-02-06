public protocol KeyedEncodingContainerProtocol {
    associatedtype Key: CodingKey
    mutating func encodeNil(forKey key: Key) throws
    mutating func encode(_ value: Bool, forKey key: Key) throws
    mutating func encode(_ value: String, forKey key: Key) throws
    mutating func encode(_ value: Double, forKey key: Key) throws
    mutating func encode(_ value: Float, forKey key: Key) throws
    mutating func encode(_ value: Int, forKey key: Key) throws
    mutating func encode(_ value: Int8, forKey key: Key) throws
    mutating func encode(_ value: Int16, forKey key: Key) throws
    mutating func encode(_ value: Int32, forKey key: Key) throws
    mutating func encode(_ value: Int64, forKey key: Key) throws
    mutating func encode(_ value: UInt, forKey key: Key) throws
    mutating func encode(_ value: UInt8, forKey key: Key) throws
    mutating func encode(_ value: UInt16, forKey key: Key) throws
    mutating func encode(_ value: UInt32, forKey key: Key) throws
    mutating func encode(_ value: UInt64, forKey key: Key) throws
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws
}

public struct KeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    public typealias Key = K
    private var box: _KeyedEncodingBox<Key>

    init(_ box: _KeyedEncodingBox<Key>) { self.box = box }

    public mutating func encodeNil(forKey key: Key) throws { try box.encodeNil(forKey: key) }
    public mutating func encode(_ value: Bool, forKey key: Key) throws { try box.encode(value, forKey: key) }
    public mutating func encode(_ value: String, forKey key: Key) throws { try box.encode(value, forKey: key) }
    public mutating func encode(_ value: Double, forKey key: Key) throws { try box.encode(value, forKey: key) }
    public mutating func encode(_ value: Float, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: Int, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: Int8, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: Int16, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: Int32, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: Int64, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: UInt, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: UInt8, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: UInt16, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: UInt32, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode(_ value: UInt64, forKey key: Key) throws { try box.encode(Double(value), forKey: key) }
    public mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws { try box.encode(value, forKey: key) }
}

public protocol UnkeyedEncodingContainer {
    var count: Int { get }
    mutating func encodeNil() throws
    mutating func encode(_ value: Bool) throws
    mutating func encode(_ value: String) throws
    mutating func encode(_ value: Double) throws
    mutating func encode(_ value: Float) throws
    mutating func encode(_ value: Int) throws
    mutating func encode(_ value: Int8) throws
    mutating func encode(_ value: Int16) throws
    mutating func encode(_ value: Int32) throws
    mutating func encode(_ value: Int64) throws
    mutating func encode(_ value: UInt) throws
    mutating func encode(_ value: UInt8) throws
    mutating func encode(_ value: UInt16) throws
    mutating func encode(_ value: UInt32) throws
    mutating func encode(_ value: UInt64) throws
    mutating func encode<T: Encodable>(_ value: T) throws
}

public protocol SingleValueEncodingContainer {
    mutating func encodeNil() throws
    mutating func encode(_ value: Bool) throws
    mutating func encode(_ value: String) throws
    mutating func encode(_ value: Double) throws
    mutating func encode(_ value: Float) throws
    mutating func encode(_ value: Int) throws
    mutating func encode(_ value: Int8) throws
    mutating func encode(_ value: Int16) throws
    mutating func encode(_ value: Int32) throws
    mutating func encode(_ value: Int64) throws
    mutating func encode(_ value: UInt) throws
    mutating func encode(_ value: UInt8) throws
    mutating func encode(_ value: UInt16) throws
    mutating func encode(_ value: UInt32) throws
    mutating func encode(_ value: UInt64) throws
    mutating func encode<T: Encodable>(_ value: T) throws
}
