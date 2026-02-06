// http+JSON.swift
// HTTP JSON bridge to Essentials (Embedded Swift, no Foundation)
//
// This file keeps compatibility with existing HTTP code that expects:
// - JSONValue
// - JSONParser.parse(...)
// - JSONValue.encodeUTF8()
//
// Internally it delegates everything to Essentials JSON.

public typealias JSONValue = EssentialsJSONValue

public enum JSONParser {
    @inline(__always)
    public static func parse(_ bytes: [U8]) -> JSONValue? {
        let ser = EssentialsJSONSerialization()
        return try? ser.jsonObject(with: Data(bytes))
    }
}

public extension EssentialsJSONValue {
    @inline(__always)
    func encodeUTF8() -> [U8] {
        EssentialsJSONSerialization.data(from: self).toArray()
    }
}