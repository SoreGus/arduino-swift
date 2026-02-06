public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(JSONNumber)
    case string(String)
    case array([JSONValue])
    case object([(String, JSONValue)])

    public subscript(key: String) -> JSONValue? {
        guard case .object(let pairs) = self else { return nil }
        for (k, v) in pairs where k == key { return v }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var intValue: Int? {
        if case .number(let n) = self {
            let i = Int(n)
            return Double(i) == n ? i : nil
        }
        return nil
    }

    public var doubleValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }
}
