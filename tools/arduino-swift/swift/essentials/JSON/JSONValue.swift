// JSONValue.swift

public enum EssentialsJSONValue: Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([EssentialsJSONValue])
    case object([(String, EssentialsJSONValue)])
}

public extension EssentialsJSONValue {
    @inline(__always)
    func encodeUTF8() -> [U8] {
        JSONSerialization.data(from: self).toArray()
    }
}
