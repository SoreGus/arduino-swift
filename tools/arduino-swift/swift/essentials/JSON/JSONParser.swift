struct JSONParser {
    private let bytes: [Byte]
    private var i: Int = 0

    init(_ bytes: [Byte]) {
        self.bytes = bytes
    }

    mutating func parse() throws -> JSONValue {
        skipWhitespace()
        let value = try parseValue()
        skipWhitespace()
        guard i == bytes.count else { throw EssentialsError.invalidJSON }
        return value
    }

    private mutating func parseValue() throws -> JSONValue {
        guard let b = peek() else { throw EssentialsError.invalidJSON }

        switch b {
        case ASCII.quote:
            return .string(try parseString())
        case ASCII.lbrace:
            return .object(try parseObject())
        case ASCII.lbracket:
            return .array(try parseArray())
        case Byte(ascii: "t"):
            try expectKeyword("true"); return .bool(true)
        case Byte(ascii: "f"):
            try expectKeyword("false"); return .bool(false)
        case Byte(ascii: "n"):
            try expectKeyword("null"); return .null
        case Byte(ascii: "-"), Byte(ascii: "0")...Byte(ascii: "9"):
            return .number(try parseNumber())
        default:
            throw EssentialsError.invalidJSON
        }
    }

    private mutating func parseObject() throws -> [(String, JSONValue)] {
        try consume(ASCII.lbrace)
        skipWhitespace()

        var pairs: [(String, JSONValue)] = []

        if peek() == ASCII.rbrace {
            _ = advance()
            return pairs
        }

        while true {
            skipWhitespace()
            guard peek() == ASCII.quote else { throw EssentialsError.invalidJSON }
            let key = try parseString()

            skipWhitespace()
            try consume(ASCII.colon)
            skipWhitespace()

            let value = try parseValue()
            pairs.append((key, value))

            skipWhitespace()
            if peek() == ASCII.comma {
                _ = advance()
                continue
            } else if peek() == ASCII.rbrace {
                _ = advance()
                return pairs
            } else {
                throw EssentialsError.invalidJSON
            }
        }
    }

    private mutating func parseArray() throws -> [JSONValue] {
        try consume(ASCII.lbracket)
        skipWhitespace()

        var values: [JSONValue] = []

        if peek() == ASCII.rbracket {
            _ = advance()
            return values
        }

        while true {
            values.append(try parseValue())
            skipWhitespace()

            if peek() == ASCII.comma {
                _ = advance()
                skipWhitespace()
            } else if peek() == ASCII.rbracket {
                _ = advance()
                return values
            } else {
                throw EssentialsError.invalidJSON
            }
        }
    }

    private mutating func parseString() throws -> String {
        try consume(ASCII.quote)
        var out: [Byte] = []

        while let b = advance() {
            if b == ASCII.quote {
                guard let s = String(bytes: out, encoding: .utf8) else {
                    throw EssentialsError.invalidUTF8
                }
                return s
            }

            if b == ASCII.backslash {
                guard let esc = advance() else { throw EssentialsError.invalidJSON }
                switch esc {
                case Byte(ascii: "\""): out.append(Byte(ascii: "\""))
                case Byte(ascii: "\\"): out.append(Byte(ascii: "\\"))
                case Byte(ascii: "/"):  out.append(Byte(ascii: "/"))
                case Byte(ascii: "b"):  out.append(0x08)
                case Byte(ascii: "f"):  out.append(0x0C)
                case Byte(ascii: "n"):  out.append(0x0A)
                case Byte(ascii: "r"):  out.append(0x0D)
                case Byte(ascii: "t"):  out.append(0x09)
                case Byte(ascii: "u"):
                    let scalar = try parseUnicodeScalar()
                    out.append(contentsOf: String(scalar).utf8)
                default:
                    throw EssentialsError.invalidJSON
                }
            } else {
                out.append(b)
            }
        }

        throw EssentialsError.invalidJSON
    }

    private mutating func parseUnicodeScalar() throws -> Unicode.Scalar {
        let h1 = try readHexNibble()
        let h2 = try readHexNibble()
        let h3 = try readHexNibble()
        let h4 = try readHexNibble()
        let value = (h1 << 12) | (h2 << 8) | (h3 << 4) | h4
        guard let scalar = Unicode.Scalar(value) else { throw EssentialsError.invalidJSON }
        return scalar
    }

    private mutating func parseNumber() throws -> Double {
        let start = i

        if peek() == Byte(ascii: "-") { _ = advance() }

        guard let first = peek() else { throw EssentialsError.invalidJSON }
        if first == Byte(ascii: "0") {
            _ = advance()
        } else if first >= Byte(ascii: "1"), first <= Byte(ascii: "9") {
            while let b = peek(), b >= Byte(ascii: "0"), b <= Byte(ascii: "9") { _ = advance() }
        } else {
            throw EssentialsError.invalidJSON
        }

        if peek() == Byte(ascii: ".") {
            _ = advance()
            guard let b = peek(), b >= Byte(ascii: "0"), b <= Byte(ascii: "9") else { throw EssentialsError.invalidJSON }
            while let b = peek(), b >= Byte(ascii: "0"), b <= Byte(ascii: "9") { _ = advance() }
        }

        if let b = peek(), b == Byte(ascii: "e") || b == Byte(ascii: "E") {
            _ = advance()
            if let sign = peek(), sign == Byte(ascii: "+") || sign == Byte(ascii: "-") { _ = advance() }
            guard let d = peek(), d >= Byte(ascii: "0"), d <= Byte(ascii: "9") else { throw EssentialsError.invalidJSON }
            while let d = peek(), d >= Byte(ascii: "0"), d <= Byte(ascii: "9") { _ = advance() }
        }

        let raw = Array(bytes[start..<i])
        guard let text = String(bytes: raw, encoding: .utf8), let number = Double(text) else {
            throw EssentialsError.invalidNumber
        }
        return number
    }

    private mutating func skipWhitespace() {
        while let b = peek(), b == ASCII.space || b == ASCII.tab || b == ASCII.lf || b == ASCII.cr {
            _ = advance()
        }
    }

    private func peek() -> Byte? {
        guard i < bytes.count else { return nil }
        return bytes[i]
    }

    @discardableResult
    private mutating func advance() -> Byte? {
        guard i < bytes.count else { return nil }
        defer { i += 1 }
        return bytes[i]
    }

    private mutating func consume(_ expected: Byte) throws {
        guard let b = advance(), b == expected else { throw EssentialsError.invalidJSON }
    }

    private mutating func expectKeyword(_ keyword: String) throws {
        for b in keyword.utf8 {
            guard advance() == b else { throw EssentialsError.invalidJSON }
        }
    }

    private mutating func readHexNibble() throws -> UInt32 {
        guard let b = advance() else { throw EssentialsError.invalidJSON }
        switch b {
        case Byte(ascii: "0")...Byte(ascii: "9"): return UInt32(b - Byte(ascii: "0"))
        case Byte(ascii: "a")...Byte(ascii: "f"): return UInt32(10 + b - Byte(ascii: "a"))
        case Byte(ascii: "A")...Byte(ascii: "F"): return UInt32(10 + b - Byte(ascii: "A"))
        default: throw EssentialsError.invalidJSON
        }
    }
}
