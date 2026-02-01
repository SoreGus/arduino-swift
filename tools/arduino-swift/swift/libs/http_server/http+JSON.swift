// http+JSON.swift
// Lightweight JSON encoder + parser (no Foundation)

public enum JSONValue: Sendable {
    case null
    case bool(Bool)
    case number(I32)
    case numberF(F32)
    case string(String)
    case array([JSONValue])
    case object([(String, JSONValue)])

    public func encodeUTF8() -> [U8] {
        var out: [U8] = []
        out.reserveCapacity(64)
        encode(into: &out)
        return out
    }

    private func encode(into out: inout [U8]) {
        switch self {
        case .null:
            out += Array("null".utf8)

        case .bool(let b):
            out += Array((b ? "true" : "false").utf8)

        case .number(let n):
            out += ASCII.intToBytes(n)

        case .numberF(let f):
            out += ASCII.floatToBytes(f, decimals: 4)

        case .string(let s):
            out.append(0x22)
            encodeJSONString(s, into: &out)
            out.append(0x22)

        case .array(let arr):
            out.append(0x5B)
            var first = true
            for v in arr {
                if !first { out.append(0x2C) }
                first = false
                v.encode(into: &out)
            }
            out.append(0x5D)

        case .object(let obj):
            out.append(0x7B)
            var first = true
            for (k, v) in obj {
                if !first { out.append(0x2C) }
                first = false
                out.append(0x22)
                encodeJSONString(k, into: &out)
                out.append(0x22)
                out.append(0x3A)
                v.encode(into: &out)
            }
            out.append(0x7D)
        }
    }
}

@inline(__always)
private func encodeJSONString(_ s: String, into out: inout [U8]) {
    for b in s.utf8 {
        switch b {
        case 0x5C: out += Array("\\\\".utf8)
        case 0x22: out += Array("\\\"".utf8)
        case 0x0A: out += Array("\\n".utf8)
        case 0x0D: out += Array("\\r".utf8)
        case 0x09: out += Array("\\t".utf8)
        default:   out.append(b)
        }
    }
}

// ============================================================
// Lightweight JSON parser (no Foundation)
// - Supports: object/array/string/number(int/float)/bool/null + basic escapes
// - Not supported: \uXXXX, scientific notation (1e-3)
// ============================================================

public enum JSONParser {

    public static func parse(_ bytes: [U8]) -> JSONValue? {
        var p = Parser(bytes)
        p.skipWS()
        guard let v = p.parseValue() else { return nil }
        p.skipWS()
        return p.isAtEnd ? v : nil
    }

    private struct Parser {
        let b: [U8]
        var i: Int = 0

        init(_ b: [U8]) { self.b = b }

        var isAtEnd: Bool { i >= b.count }

        mutating func skipWS() {
            while i < b.count {
                let c = b[i]
                if c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 { i += 1 }
                else { break }
            }
        }

        mutating func parseValue() -> JSONValue? {
            skipWS()
            if isAtEnd { return nil }

            switch b[i] {
            case 0x7B: return parseObject()        // {
            case 0x5B: return parseArray()         // [
            case 0x22: return parseStringValue()   // "
            case 0x74: return parseLiteral("true",  value: .bool(true))
            case 0x66: return parseLiteral("false", value: .bool(false))
            case 0x6E: return parseLiteral("null",  value: .null)
            case 0x2D, 0x30...0x39:
                return parseNumber()
            default:
                return nil
            }
        }

        mutating func parseLiteral(_ s: String, value: JSONValue) -> JSONValue? {
            let lit = Array(s.utf8)
            if i + lit.count > b.count { return nil }
            var k = 0
            while k < lit.count {
                if b[i + k] != lit[k] { return nil }
                k += 1
            }
            i += lit.count
            return value
        }

        mutating func parseObject() -> JSONValue? {
            i += 1 // {
            skipWS()

            var items: [(String, JSONValue)] = []
            items.reserveCapacity(8)

            if consume(0x7D) { return .object(items) } // }

            while true {
                skipWS()
                guard let key = parseString() else { return nil }
                skipWS()
                guard consume(0x3A) else { return nil } // :
                skipWS()
                guard let val = parseValue() else { return nil }
                items.append((key, val))
                skipWS()

                if consume(0x2C) { // ,
                    continue
                } else if consume(0x7D) { // }
                    break
                } else {
                    return nil
                }
            }

            return .object(items)
        }

        mutating func parseArray() -> JSONValue? {
            i += 1 // [
            skipWS()

            var arr: [JSONValue] = []
            arr.reserveCapacity(8)

            if consume(0x5D) { return .array(arr) } // ]

            while true {
                skipWS()
                guard let v = parseValue() else { return nil }
                arr.append(v)
                skipWS()

                if consume(0x2C) { // ,
                    continue
                } else if consume(0x5D) { // ]
                    break
                } else {
                    return nil
                }
            }

            return .array(arr)
        }

        mutating func parseStringValue() -> JSONValue? {
            guard let s = parseString() else { return nil }
            return .string(s)
        }

        mutating func parseString() -> String? {
            guard consume(0x22) else { return nil } // "

            var out: [U8] = []
            out.reserveCapacity(32)

            while i < b.count {
                let c = b[i]
                i += 1

                if c == 0x22 { // "
                    return ASCII.stringFromBytes(out)
                }

                if c == 0x5C { // \
                    if i >= b.count { return nil }
                    let e = b[i]
                    i += 1
                    switch e {
                    case 0x22: out.append(0x22) // "
                    case 0x5C: out.append(0x5C) // \
                    case 0x6E: out.append(0x0A) // n -> \n
                    case 0x72: out.append(0x0D) // r -> \r
                    case 0x74: out.append(0x09) // t -> \t
                    default:
                        return nil // \uXXXX etc.
                    }
                } else {
                    out.append(c)
                }
            }

            return nil
        }

        // Supports "-123", "3.1416" (no exponent)
        mutating func parseNumber() -> JSONValue? {
            let start = i

            _ = consume(0x2D) // '-'

            var intDigits = 0
            while i < b.count {
                let c = b[i]
                if c < 0x30 || c > 0x39 { break }
                intDigits += 1
                i += 1
            }
            if intDigits == 0 { i = start; return nil }

            var hasDot = false
            if i < b.count, b[i] == 0x2E { // '.'
                hasDot = true
                i += 1

                var fracDigits = 0
                while i < b.count {
                    let c = b[i]
                    if c < 0x30 || c > 0x39 { break }
                    fracDigits += 1
                    i += 1
                }
                if fracDigits == 0 { i = start; return nil } // "3." invalid
            }

            let slice = Array(b[start..<i])

            if !hasDot {
                guard let n = ASCII.parseInt(slice) else { return nil }
                if n < Int(Int32.min) || n > Int(Int32.max) { return nil }
                return .number(I32(n))
            } else {
                guard let f = ASCII.parseFloat(slice) else { return nil }
                return .numberF(f)
            }
        }

        mutating func consume(_ byte: U8) -> Bool {
            if i < b.count, b[i] == byte {
                i += 1
                return true
            }
            return false
        }
    }
}