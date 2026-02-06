public extension String {
    @inline(__always)
    var asciiBytes: [UInt8] { Array(self.utf8) }

    @inline(__always)
    static func fromASCIILossy(_ bytes: [UInt8]) -> String {
        if bytes.isEmpty { return "" }
        var out = String()
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b >= 32 && b <= 126 {
                out.append(Character(UnicodeScalar(Int(b))!))
            } else if b == 10 || b == 13 || b == 9 {
                out.append(Character(UnicodeScalar(Int(b))!))
            } else {
                out.append("?")
            }
            i += 1
        }
        return out
    }
}
