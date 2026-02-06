// JSONCodable.swift
// Embedded-safe JSON coding API (no stdlib Encoder/Decoder container internals)

public protocol EssentialsJSONCodable: Sendable {
    init(json: EssentialsJSONValue) throws(EssentialsError)
    func toJSON() throws(EssentialsError) -> EssentialsJSONValue
}

public struct JSONDecoder {
    public init() {}

    @inline(__always)
    public func decode<T: EssentialsJSONCodable>(_ type: T.Type, from data: Data) throws(EssentialsError) -> T {
        _ = type
        let (root, err) = JSONSerialization().jsonObject(with: data)
        if err != .none { throw err }
        guard let root else { throw .invalidJSON }
        return try T(json: root)
    }
}

public struct JSONEncoder {
    public init() {}

    @inline(__always)
    public func encode<T: EssentialsJSONCodable>(_ value: T) throws(EssentialsError) -> Data {
        let json = try value.toJSON()
        return JSONSerialization.data(from: json)
    }
}

// MARK: - Primitive conformances

extension String: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        guard case .string(let s) = json else { throw .typeMismatch }
        self = s
    }

    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .string(self) }
}

extension Bool: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        guard case .bool(let b) = json else { throw .typeMismatch }
        self = b
    }

    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .bool(self) }
}

extension Int: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        guard case .number(let n) = json else { throw .typeMismatch }
        self = Int(n)
    }

    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}

extension Double: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        guard case .number(let n) = json else { throw .typeMismatch }
        self = n
    }

    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(self) }
}

extension Float: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        guard case .number(let n) = json else { throw .typeMismatch }
        self = Float(n)
    }

    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}

extension Int8: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) { self = Int8(try Int(json: json)) }
    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}
extension Int16: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) { self = Int16(try Int(json: json)) }
    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}
extension Int32: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) { self = Int32(try Int(json: json)) }
    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}
extension Int64: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        guard case .number(let n) = json else { throw .typeMismatch }
        self = Int64(n)
    }
    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}

extension UInt: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        let v = try Int(json: json)
        if v < 0 { throw .outOfRange }
        self = UInt(v)
    }
    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}
extension UInt8: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) { self = UInt8(try UInt(json: json)) }
    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}
extension UInt16: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) { self = UInt16(try UInt(json: json)) }
    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}
extension UInt32: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) { self = UInt32(try UInt(json: json)) }
    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}
extension UInt64: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        guard case .number(let n) = json else { throw .typeMismatch }
        if n < 0 { throw .outOfRange }
        self = UInt64(n)
    }
    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue { .number(Double(self)) }
}

// MARK: - Optional / Array / Dictionary

extension Optional: EssentialsJSONCodable where Wrapped: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        if case .null = json {
            self = .none
        } else {
            self = .some(try Wrapped(json: json))
        }
    }

    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue {
        switch self {
        case .none: return .null
        case .some(let w): return try w.toJSON()
        }
    }
}

extension Array: EssentialsJSONCodable where Element: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        guard case .array(let a) = json else { throw .typeMismatch }
        var out: [Element] = []
        out.reserveCapacity(a.count)
        var i = 0
        while i < a.count {
            out.append(try Element(json: a[i]))
            i += 1
        }
        self = out
    }

    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue {
        var out: [EssentialsJSONValue] = []
        out.reserveCapacity(self.count)
        var i = 0
        while i < self.count {
            out.append(try self[i].toJSON())
            i += 1
        }
        return .array(out)
    }
}

extension Dictionary: EssentialsJSONCodable where Key == String, Value: EssentialsJSONCodable {
    public init(json: EssentialsJSONValue) throws(EssentialsError) {
        guard case .object(let o) = json else { throw .typeMismatch }
        var d: [String: Value] = [:]
        var i = 0
        while i < o.count {
            d[o[i].0] = try Value(json: o[i].1)
            i += 1
        }
        self = d
    }

    public func toJSON() throws(EssentialsError) -> EssentialsJSONValue {
        var o: [(String, EssentialsJSONValue)] = []
        o.reserveCapacity(self.count)
        for (k, v) in self {
            o.append((k, try v.toJSON()))
        }
        return .object(o)
    }
}
