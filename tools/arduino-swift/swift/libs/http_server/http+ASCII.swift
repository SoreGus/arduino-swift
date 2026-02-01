// http+ASCII.swift
// Byte/ASCII helpers (no Foundation)

public enum ASCII {

    // MARK: - Lower / Compare

    @inline(__always)
    public static func lower(_ b: U8) -> U8 {
        if b >= 0x41 && b <= 0x5A { return b &+ 0x20 }
        return b
    }

    @inline(__always)
    public static func equal(_ a: [U8], _ b: [U8]) -> Bool {
        if a.count != b.count { return false }
        var i = 0
        while i < a.count {
            if a[i] != b[i] { return false }
            i += 1
        }
        return true
    }

    @inline(__always)
    public static func caseInsensitiveEqual(_ a: [U8], _ b: [U8]) -> Bool {
        if a.count != b.count { return false }
        var i = 0
        while i < a.count {
            if lower(a[i]) != lower(b[i]) { return false }
            i += 1
        }
        return true
    }

    @inline(__always)
    public static func hasPrefixCaseInsensitive(_ bytes: [U8], _ prefix: [U8]) -> Bool {
        if bytes.count < prefix.count { return false }
        var i = 0
        while i < prefix.count {
            if lower(bytes[i]) != lower(prefix[i]) { return false }
            i += 1
        }
        return true
    }

    // MARK: - Trim

    @inline(__always)
    public static func ltrimSpaces(_ bytes: [U8]) -> [U8] {
        var i = 0
        while i < bytes.count && (bytes[i] == 0x20 || bytes[i] == 0x09) { i += 1 }
        if i == 0 { return bytes }
        return Array(bytes[i..<bytes.count])
    }

    @inline(__always)
    public static func rtrimSpaces(_ bytes: [U8]) -> [U8] {
        if bytes.isEmpty { return bytes }
        var j = bytes.count - 1
        while true {
            let b = bytes[j]
            if b != 0x20 && b != 0x09 { break }
            if j == 0 { return [] }
            j -= 1
        }
        return Array(bytes[0...j])
    }

    // MARK: - Find

    @inline(__always)
    public static func findByte(_ bytes: [U8], byte: U8, start: Int) -> Int? {
        var i = start
        while i < bytes.count {
            if bytes[i] == byte { return i }
            i += 1
        }
        return nil
    }

    @inline(__always)
    public static func findCRLF(_ bytes: [U8], start: Int) -> Int? {
        var i = start + 1
        while i < bytes.count {
            if bytes[i - 1] == 13 && bytes[i] == 10 { return i - 1 }
            i += 1
        }
        return nil
    }

    // MARK: - Parse Int / Float (ASCII)

    @inline(__always)
    public static func parseInt(_ bytes: [U8]) -> Int? {
        var i = 0
        while i < bytes.count && (bytes[i] == 0x20 || bytes[i] == 0x09) { i += 1 }
        if i >= bytes.count { return nil }

        var sign = 1
        if bytes[i] == 0x2D { sign = -1; i += 1 }

        var val = 0
        var any = false
        while i < bytes.count {
            let b = bytes[i]
            if b < 0x30 || b > 0x39 { break }
            any = true
            val = val * 10 + Int(b - 0x30)
            i += 1
        }

        return any ? (val * sign) : nil
    }

    /// Supports "-123", "3.1416" (no exponent). Requires digits before '.' and after '.' if '.' exists.
    @inline(__always)
    public static func parseFloat(_ bytes: [U8]) -> F32? {
        var i = 0
        while i < bytes.count && (bytes[i] == 0x20 || bytes[i] == 0x09) { i += 1 }
        if i >= bytes.count { return nil }

        var sign: F32 = F32(1)
        if bytes[i] == 0x2D { sign = -F32(1); i += 1 }

        var intPart: F32 = F32(0)
        var anyInt = false
        while i < bytes.count {
            let c = bytes[i]
            if c < 0x30 || c > 0x39 { break }
            anyInt = true
            intPart = intPart * F32(10) + F32(Int(c - 0x30))
            i += 1
        }
        if !anyInt { return nil }

        var fracPart: F32 = F32(0)
        var fracDiv: F32 = F32(1)

        if i < bytes.count, bytes[i] == 0x2E { // '.'
            i += 1
            var anyFrac = false
            while i < bytes.count {
                let c = bytes[i]
                if c < 0x30 || c > 0x39 { break }
                anyFrac = true
                fracPart = fracPart * F32(10) + F32(Int(c - 0x30))
                fracDiv *= F32(10)
                i += 1
            }
            if !anyFrac { return nil } // "3." invalid
        }

        return sign * (intPart + (fracPart / fracDiv))
    }

    // MARK: - Encode Int / Float -> bytes

    @inline(__always)
    public static func intToBytes(_ v: I32) -> [U8] {
        var n = v
        if n == 0 { return [0x30] }

        var out: [U8] = []
        if n < 0 { out.append(0x2D); n = -n }

        var tmp: [U8] = []
        while n > 0 {
            let d = U8(n % 10)
            tmp.append(0x30 &+ d)
            n /= 10
        }

        var i = tmp.count
        while i > 0 {
            i -= 1
            out.append(tmp[i])
        }
        return out
    }

    @inline(__always)
    private static func pow10F32(_ n: I32) -> F32 {
        var r: F32 = F32(1)
        var k = n
        while k > 0 {
            r *= F32(10)
            k -= 1
        }
        return r
    }

    /// Fixed decimals encoder (simple, no Foundation). Clamps NaN/Inf to "0".
    @inline(__always)
    public static func floatToBytes(_ f: F32, decimals: I32) -> [U8] {
        var x = f
        if x.isNaN || x.isInfinite { return [0x30] }

        var out: [U8] = []
        if x < F32(0) {
            out.append(0x2D)
            x = -x
        }

        let scale: F32 = pow10F32(decimals)
        let scaled: I32 = I32(x * scale + F32(0.5)) // round
        let intPart: I32 = scaled / I32(scale)
        let fracPart: I32 = scaled % I32(scale)

        out += intToBytes(intPart)

        if decimals > 0 {
            out.append(0x2E)

            let fracStr = intToBytes(fracPart)
            let need = Int(decimals) - fracStr.count
            if need > 0 { out += [U8](repeating: 0x30, count: need) }
            out += fracStr
        }

        return out
    }

    // MARK: - Bytes <-> String (ASCII / UTF-8 passthrough)

    @inline(__always)
    public static func stringFromBytes(_ bytes: [U8]) -> String {
        var buf = [CChar](repeating: 0, count: bytes.count + 1)
        var i = 0
        while i < bytes.count {
            buf[i] = CChar(bitPattern: bytes[i])
            i += 1
        }
        return String(cString: buf)
    }

    @inline(__always)
    public static func staticUTF8(_ s: StaticString) -> [U8] {
        let utf8 = s.utf8Start
        let len = s.utf8CodeUnitCount
        var out: [U8] = []
        out.reserveCapacity(len)
        var i = 0
        while i < len {
            out.append(U8(utf8[i]))
            i += 1
        }
        return out
    }
}