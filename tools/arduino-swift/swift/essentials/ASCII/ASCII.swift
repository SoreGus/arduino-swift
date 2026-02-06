// ASCII.swift
// Essentials ASCII helpers (embedded-safe)

public enum ASCII {

    // ------------------------------------------------------------
    // MARK: - Conversions
    // ------------------------------------------------------------

    @inline(__always)
    public static func staticUTF8(_ s: StaticString) -> [U8] {
        var out: [U8] = []
        out.reserveCapacity(s.utf8CodeUnitCount)
        s.withUTF8Buffer { buf in
            for b in buf { out.append(U8(b)) }
        }
        return out
    }

    @inline(__always)
    public static func stringFromBytes(_ bytes: [U8]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }

    /// Decimal Int -> ASCII bytes (e.g. 200 -> [50,48,48] => "200")
    @inline(__always)
    public static func intToBytes<T: BinaryInteger>(_ value: T) -> [U8] {
        if value == 0 { return [48] } // "0"

        var n = value
        let isNegative = n < 0
        if isNegative { n = 0 - n }

        var rev: [U8] = []
        rev.reserveCapacity(20) // enough for common embedded integer sizes

        while n > 0 {
            let digit = U8(n % 10)
            rev.append(48 &+ digit)
            n /= 10
        }

        var out: [U8] = []
        out.reserveCapacity(rev.count + (isNegative ? 1 : 0))
        if isNegative { out.append(45) } // '-'

        var i = rev.count
        while i > 0 {
            i &-= 1
            out.append(rev[i])
        }
        return out
    }

    // ------------------------------------------------------------
    // MARK: - Byte case helpers
    // ------------------------------------------------------------

    @inline(__always)
    private static func lower(_ b: U8) -> U8 {
        (b >= 65 && b <= 90) ? (b &+ 32) : b // A...Z -> a...z
    }

    // ------------------------------------------------------------
    // MARK: - Comparisons
    // ------------------------------------------------------------

    @inline(__always)
    public static func equal(_ a: [U8], _ b: [U8]) -> Bool {
        if a.count != b.count { return false }
        var i = 0
        while i < a.count {
            if a[i] != b[i] { return false }
            i &+= 1
        }
        return true
    }

    @inline(__always)
    public static func caseInsensitiveEqual(_ a: [U8], _ b: [U8]) -> Bool {
        if a.count != b.count { return false }
        var i = 0
        while i < a.count {
            if lower(a[i]) != lower(b[i]) { return false }
            i &+= 1
        }
        return true
    }

    @inline(__always)
    public static func hasPrefixCaseInsensitive(_ s: [U8], _ prefix: [U8]) -> Bool {
        if prefix.count > s.count { return false }
        var i = 0
        while i < prefix.count {
            if lower(s[i]) != lower(prefix[i]) { return false }
            i &+= 1
        }
        return true
    }

    // ------------------------------------------------------------
    // MARK: - Search
    // ------------------------------------------------------------

    @inline(__always)
    public static func findByte(_ s: [U8], byte: U8, start: Int = 0) -> Int? {
        if s.isEmpty || start < 0 || start >= s.count { return nil }
        var i = start
        while i < s.count {
            if s[i] == byte { return i }
            i &+= 1
        }
        return nil
    }

    @inline(__always)
    public static func findCRLF(_ s: [U8], start: Int = 0) -> Int? {
        if s.count < 2 || start < 0 || start >= s.count - 1 { return nil }
        var i = start
        while i + 1 < s.count {
            if s[i] == 13 && s[i + 1] == 10 { return i } // \r\n
            i &+= 1
        }
        return nil
    }

    // ------------------------------------------------------------
    // MARK: - Trimming
    // ------------------------------------------------------------

    @inline(__always)
    public static func ltrimSpaces(_ s: [U8]) -> [U8] {
        var i = 0
        while i < s.count && (s[i] == 32 || s[i] == 9) { i &+= 1 } // space/tab
        return i == 0 ? s : Array(s[i..<s.count])
    }

    @inline(__always)
    public static func rtrimSpaces(_ s: [U8]) -> [U8] {
        if s.isEmpty { return s }
        var j = s.count
        while j > 0 {
            let c = s[j - 1]
            if c == 32 || c == 9 { j &-= 1 } else { break } // space/tab
        }
        return j == s.count ? s : Array(s[0..<j])
    }

    // ------------------------------------------------------------
    // MARK: - Parsing
    // ------------------------------------------------------------

    @inline(__always)
    public static func parseInt(_ s: [U8]) -> Int? {
        if s.isEmpty { return nil }

        var i = 0
        var sign = 1

        if s[0] == 45 { sign = -1; i = 1 }      // '-'
        else if s[0] == 43 { i = 1 }            // '+'

        if i >= s.count { return nil }

        var value = 0
        var hasDigit = false

        while i < s.count {
            let c = s[i]
            if c < 48 || c > 57 { break }       // not 0...9
            hasDigit = true
            value = value &* 10 &+ Int(c - 48)  // wrap-safe arithmetic style
            i &+= 1
        }

        return hasDigit ? value * sign : nil
    }
}