// ============================================================
// ArduinoSwift - application/x-www-form-urlencoded parser
// File: swift/libs/http/FormURLEncoded.swift
// ============================================================

public struct FormURLEncoded: Sendable {
    private let raw: [U8]

    public init(_ body: [U8]) {
        self.raw = body
    }

    public func value(_ key: String) -> String? {
        let k = Array(key.utf8)
        var i = 0

        while i < raw.count {
            var keyBytes: [U8] = []
            while i < raw.count, raw[i] != 61, raw[i] != 38 { // '=' '&'
                keyBytes.append(raw[i]); i += 1
            }

            var valBytes: [U8] = []
            if i < raw.count, raw[i] == 61 {
                i += 1
                while i < raw.count, raw[i] != 38 {
                    valBytes.append(raw[i]); i += 1
                }
            }

            if i < raw.count, raw[i] == 38 { i += 1 }

            if HTTPBytes.eq(decode(keyBytes), k) {
                return HTTPBytes.toString(decode(valBytes))
            }
        }

        return nil
    }

    private func decode(_ s: [U8]) -> [U8] {
        var out: [U8] = []
        out.reserveCapacity(s.count)

        var i = 0
        while i < s.count {
            let c = s[i]
            if c == 43 { out.append(32); i += 1; continue } // '+'
            if c == 37, i + 2 < s.count { // '%'
                if let b = hexByte(s[i+1], s[i+2]) {
                    out.append(b); i += 3; continue
                }
            }
            out.append(c); i += 1
        }
        return out
    }

    private func hexByte(_ a: U8, _ b: U8) -> U8? {
        guard let hi = hexNibble(a), let lo = hexNibble(b) else { return nil }
        return (hi << 4) | lo
    }

    private func hexNibble(_ c: U8) -> U8? {
        if c >= 48 && c <= 57 { return c &- 48 }
        if c >= 65 && c <= 70 { return c &- 55 }
        if c >= 97 && c <= 102 { return c &- 87 }
        return nil
    }
}