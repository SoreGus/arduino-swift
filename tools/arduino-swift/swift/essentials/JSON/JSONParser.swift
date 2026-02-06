// JSONParser.swift

struct EssentialsJSONParser {
    private var bytes: [UInt8]
    private var i: Int = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func parse() -> (EssentialsJSONValue?, EssentialsError) {
        skipWS()
        let (v, e) = parseValue()
        if e != .none { return (nil, e) }
        skipWS()
        if i != bytes.count { return (nil, .invalidJSON) }
        return (v, .none)
    }

    private mutating func parseValue() -> (EssentialsJSONValue?, EssentialsError) {
        guard let b = peek() else { return (nil, .unexpectedEOF) }

        switch b {
        case 0x7B: // {
            let (obj, e) = parseObject()
            if e != .none { return (nil, e) }
            return (.object(obj ?? []), .none)

        case 0x5B: // [
            let (arr, e) = parseArray()
            if e != .none { return (nil, e) }
            return (.array(arr ?? []), .none)

        case 0x22: // "
            let (s, e) = parseString()
            if e != .none { return (nil, e) }
            return (.string(s ?? ""), .none)

        case 0x74: // true
            let e = expectKeyword([0x74,0x72,0x75,0x65])
            return e == .none ? (.bool(true), .none) : (nil, e)

        case 0x66: // false
            let e = expectKeyword([0x66,0x61,0x6C,0x73,0x65])
            return e == .none ? (.bool(false), .none) : (nil, e)

        case 0x6E: // null
            let e = expectKeyword([0x6E,0x75,0x6C,0x6C])
            return e == .none ? (.null, .none) : (nil, e)

        default:
            let (n, e) = parseNumber()
            if e != .none { return (nil, e) }
            return (.number(n ?? 0), .none)
        }
    }

    private mutating func parseObject() -> ([(String, EssentialsJSONValue)]?, EssentialsError) {
        let c = consume(0x7B) // {
        if c != .none { return (nil, c) }
        skipWS()

        var items: [(String, EssentialsJSONValue)] = []
        if peek() == 0x7D { // }
            _ = advance()
            return (items, .none)
        }

        while true {
            skipWS()
            let (k, ke) = parseString()
            if ke != .none { return (nil, ke) }
            skipWS()

            let ce = consume(0x3A) // :
            if ce != .none { return (nil, ce) }
            skipWS()

            let (v, ve) = parseValue()
            if ve != .none { return (nil, ve) }
            items.append((k ?? "", v ?? .null))
            skipWS()

            guard let sep = advance() else { return (nil, .invalidJSON) }
            if sep == 0x7D { break } // }
            if sep != 0x2C { return (nil, .invalidJSON) } // ,
        }

        return (items, .none)
    }

    private mutating func parseArray() -> ([EssentialsJSONValue]?, EssentialsError) {
        let c = consume(0x5B) // [
        if c != .none { return (nil, c) }
        skipWS()

        var arr: [EssentialsJSONValue] = []
        if peek() == 0x5D { // ]
            _ = advance()
            return (arr, .none)
        }

        while true {
            skipWS()
            let (v, e) = parseValue()
            if e != .none { return (nil, e) }
            arr.append(v ?? .null)
            skipWS()

            guard let sep = advance() else { return (nil, .invalidJSON) }
            if sep == 0x5D { break } // ]
            if sep != 0x2C { return (nil, .invalidJSON) } // ,
        }

        return (arr, .none)
    }

    private mutating func parseString() -> (String?, EssentialsError) {
        let c = consume(0x22) // "
        if c != .none { return (nil, c) }

        var out: [UInt8] = []
        while let b = advance() {
            if b == 0x22 { // "
                return (String(decoding: out, as: UTF8.self), .none)
            }

            if b == 0x5C { // \
                guard let esc = advance() else { return (nil, .unexpectedEOF) }
                switch esc {
                case 0x22: out.append(0x22) // "
                case 0x5C: out.append(0x5C) // \
                case 0x2F: out.append(0x2F) // /
                case 0x62: out.append(0x08) // b
                case 0x66: out.append(0x0C) // f
                case 0x6E: out.append(0x0A) // n
                case 0x72: out.append(0x0D) // r
                case 0x74: out.append(0x09) // t
                case 0x75:
                    let e = consumeHex4()
                    if e != .none { return (nil, e) }
                    out.append(UInt8(ascii: "?")) // tiny parser tradeoff
                default:
                    return (nil, .unsupportedEscape)
                }
            } else {
                out.append(b)
            }
        }

        return (nil, .unexpectedEOF)
    }

    private mutating func parseNumber() -> (Double?, EssentialsError) {
        let start = i

        if peek() == 0x2D { _ = advance() } // -

        guard let first = peek() else { return (nil, .invalidNumber) }

        if first == 0x30 {
            _ = advance()
        } else {
            guard isDigit(first) else { return (nil, .invalidJSON) }
            while let d = peek(), isDigit(d) { _ = advance() }
        }

        if peek() == 0x2E {
            _ = advance()
            guard let d = peek(), isDigit(d) else { return (nil, .invalidNumber) }
            while let d2 = peek(), isDigit(d2) { _ = advance() }
        }

        if let e = peek(), (e == 0x65 || e == 0x45) {
            _ = advance()
            if let s = peek(), (s == 0x2B || s == 0x2D) { _ = advance() }
            guard let d = peek(), isDigit(d) else { return (nil, .invalidNumber) }
            while let d2 = peek(), isDigit(d2) { _ = advance() }
        }

        let token = Array(bytes[start..<i])
        let text = String(decoding: token, as: UTF8.self)
        guard let number = Double(text) else { return (nil, .invalidNumber) }
        return (number, .none)
    }

    @inline(__always) private func peek() -> UInt8? {
        if i < 0 || i >= bytes.count { return nil }
        return bytes[i]
    }

    @inline(__always) private mutating func advance() -> UInt8? {
        if i < 0 || i >= bytes.count { return nil }
        let b = bytes[i]
        i += 1
        return b
    }

    @inline(__always) private mutating func skipWS() {
        while let b = peek() {
            if b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09 {
                _ = advance()
            } else {
                break
            }
        }
    }

    private mutating func consume(_ expected: UInt8) -> EssentialsError {
        guard advance() == expected else { return .invalidJSON }
        return .none
    }

    private mutating func expectKeyword(_ kw: [UInt8]) -> EssentialsError {
        var j = 0
        while j < kw.count {
            guard advance() == kw[j] else { return .invalidJSON }
            j += 1
        }
        return .none
    }

    private mutating func consumeHex4() -> EssentialsError {
        var c = 0
        while c < 4 {
            guard let b = advance(), isHex(b) else { return .invalidJSON }
            c += 1
        }
        return .none
    }

    @inline(__always) private func isDigit(_ b: UInt8) -> Bool {
        b >= 0x30 && b <= 0x39
    }

    @inline(__always) private func isHex(_ b: UInt8) -> Bool {
        (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x46) || (b >= 0x61 && b <= 0x66)
    }
}
