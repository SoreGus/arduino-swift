public struct JSONSerialization {
    public init() {}

    public func data(from value: JSONValue) -> Data {
        Data(utf8: string(from: value))
    }

    public func string(from value: JSONValue) -> String {
        serialize(value)
    }

    public func jsonValue(from data: Data) throws -> JSONValue {
        var parser = JSONParser(data.toArray())
        return try parser.parse()
    }

    private func serialize(_ value: JSONValue) -> String {
        switch value {
        case .null:
            return "null"
        case .bool(let b):
            return b ? "true" : "false"
        case .number(let n):
            let i = Int(n)
            return (Double(i) == n) ? "\(i)" : "\(n)"
        case .string(let s):
            return "\"\(escapeJSONString(s))\""
        case .array(let arr):
            return "[\(arr.map(serialize).joined(separator: ","))]"
        case .object(let pairs):
            let body = pairs.map { "\"\(escapeJSONString($0.0))\":\(serialize($0.1))" }
                .joined(separator: ",")
            return "{\(body)}"
        }
    }

    private func escapeJSONString(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count + 8)
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x22: out += "\\\""
            case 0x5C: out += "\\\\"
            case 0x08: out += "\\b"
            case 0x0C: out += "\\f"
            case 0x0A: out += "\\n"
            case 0x0D: out += "\\r"
            case 0x09: out += "\\t"
            case 0x00...0x1F:
                let hex = String(scalar.value, radix: 16, uppercase: true)
                out += "\\u" + String(repeating: "0", count: max(0, 4 - hex.count)) + hex
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}
