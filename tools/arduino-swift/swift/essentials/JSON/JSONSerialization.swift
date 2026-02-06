// JSONSerialization.swift

public struct JSONSerialization {
    public init() {}

    @inline(__always)
    public func jsonObject(with data: Data) -> (EssentialsJSONValue?, EssentialsError) {
        var parser = EssentialsJSONParser(bytes: data.toArray())
        return parser.parse()
    }

    public static func data(from value: EssentialsJSONValue) -> Data {
        var out: [U8] = []
        out.reserveCapacity(128)
        write(value, into: &out)
        return Data(out)
    }

    private static func write(_ v: EssentialsJSONValue, into out: inout [U8]) {
        switch v {
        case .null:
            out += Array("null".utf8)

        case .bool(let b):
            out += Array((b ? "true" : "false").utf8)

        case .number(let n):
            // Keep compact representation when integral
            let i = I64(n)
            if Double(i) == n {
                out += Array("\(i)".utf8)
            } else {
                out += Array("\(n)".utf8)
            }

        case .string(let s):
            writeString(s, into: &out)

        case .array(let arr):
            out.append(0x5B) // [
            var i = 0
            while i < arr.count {
                if i > 0 { out.append(0x2C) } // ,
                write(arr[i], into: &out)
                i += 1
            }
            out.append(0x5D) // ]

        case .object(let obj):
            out.append(0x7B) // {
            var i = 0
            while i < obj.count {
                if i > 0 { out.append(0x2C) } // ,
                writeString(obj[i].0, into: &out)
                out.append(0x3A) // :
                write(obj[i].1, into: &out)
                i += 1
            }
            out.append(0x7D) // }
        }
    }

    private static func writeString(_ s: String, into out: inout [U8]) {
        out.append(0x22) // "
        for b in s.utf8 {
            switch b {
            case 0x22: out += Array("\\\"".utf8)
            case 0x5C: out += Array("\\\\".utf8)
            case 0x08: out += Array("\\b".utf8)
            case 0x0C: out += Array("\\f".utf8)
            case 0x0A: out += Array("\\n".utf8)
            case 0x0D: out += Array("\\r".utf8)
            case 0x09: out += Array("\\t".utf8)
            default:
                if b < 0x20 {
                    out += Array("\\u00".utf8)
                    out.append(hex((b >> 4) & 0xF))
                    out.append(hex(b & 0xF))
                } else {
                    out.append(b)
                }
            }
        }
        out.append(0x22) // "
    }

    @inline(__always)
    private static func hex(_ n: U8) -> U8 {
        n < 10 ? (48 + n) : (55 + n) // 0-9 A-F
    }
}
