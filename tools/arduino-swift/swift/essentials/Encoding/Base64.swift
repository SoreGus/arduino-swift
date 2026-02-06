public enum Base64 {
    private static let table: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

    public static func encode(_ bytes: [UInt8]) -> String {
        if bytes.isEmpty { return "" }
        var out: [UInt8] = []
        out.reserveCapacity(((bytes.count + 2) / 3) * 4)

        var i = 0
        while i < bytes.count {
            let b0 = UInt32(bytes[i]); i += 1
            let b1: UInt32 = i < bytes.count ? UInt32(bytes[i]) : 0; i += 1
            let b2: UInt32 = i < bytes.count ? UInt32(bytes[i]) : 0; i += 1

            let triple = (b0 << 16) | (b1 << 8) | b2

            out.append(table[Int((triple >> 18) & 0x3F)])
            out.append(table[Int((triple >> 12) & 0x3F)])

            let pad2 = (i - 1) > bytes.count
            let pad1 = i > bytes.count

            out.append(pad2 ? UInt8(ascii: "=") : table[Int((triple >> 6) & 0x3F)])
            out.append(pad1 ? UInt8(ascii: "=") : table[Int(triple & 0x3F)])
        }

        return String(decoding: out, as: UTF8.self)
    }
}
