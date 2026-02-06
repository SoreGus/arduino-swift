// http+JSON.swift
// Bridge HTTP JSON to Essentials JSON

public typealias JSONValue = EssentialsJSONValue

public enum JSONParser {
    @inline(__always)
    public static func parse(_ bytes: [U8]) -> JSONValue? {
        let (v, e) = JSONSerialization().jsonObject(with: Data(bytes))
        return e == .none ? v : nil
    }
}
