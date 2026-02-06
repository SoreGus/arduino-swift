public extension Data {
    func base64EncodedString() -> String {
        if storage.isEmpty { return "" }

        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
        var out: [Byte] = []
        out.reserveCapacity(((storage.count + 2) / 3) * 4)

        var i = 0
        while i < storage.count {
            let b0 = storage[i]
            let b1 = (i + 1 < storage.count) ? storage[i + 1] : 0
            let b2 = (i + 2 < storage.count) ? storage[i + 2] : 0

            let n = (UInt32(b0) << 16) | (UInt32(b1) << 8) | UInt32(b2)

            out.append(alphabet[Int((n >> 18) & 0x3F)])
            out.append(alphabet[Int((n >> 12) & 0x3F)])
            out.append(i + 1 < storage.count ? alphabet[Int((n >> 6) & 0x3F)] : Byte(ascii: "="))
            out.append(i + 2 < storage.count ? alphabet[Int(n & 0x3F)] : Byte(ascii: "="))

            i += 3
        }

        return String(decoding: out, as: UTF8.self)
    }

    init?(base64Encoded input: String) {
        var reverse = [Int8](repeating: -1, count: 128)
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
        for (i, c) in alphabet.enumerated() { reverse[Int(c)] = Int8(i) }

        let bytes = input.utf8.filter { b in
            b != ASCII.space && b != ASCII.tab && b != ASCII.lf && b != ASCII.cr
        }

        if bytes.isEmpty {
            self.init()
            return
        }

        guard bytes.count % 4 == 0 else { return nil }

        var out: [Byte] = []
        out.reserveCapacity((bytes.count / 4) * 3)

        var idx = 0
        while idx < bytes.count {
            let c0 = bytes[idx + 0]
            let c1 = bytes[idx + 1]
            let c2 = bytes[idx + 2]
            let c3 = bytes[idx + 3]

            guard c0 < 128, c1 < 128, c2 < 128 || c2 == Byte(ascii: "="), c3 < 128 || c3 == Byte(ascii: "=") else {
                return nil
            }

            let v0 = reverse[Int(c0)]
            let v1 = reverse[Int(c1)]
            guard v0 >= 0, v1 >= 0 else { return nil }

            let pad2 = (c2 == Byte(ascii: "="))
            let pad3 = (c3 == Byte(ascii: "="))

            var v2: Int8 = 0
            var v3: Int8 = 0

            if !pad2 {
                v2 = reverse[Int(c2)]
                guard v2 >= 0 else { return nil }
            }
            if !pad3 {
                v3 = reverse[Int(c3)]
                guard v3 >= 0 else { return nil }
            }

            let n = (UInt32(UInt8(v0)) << 18)
                  | (UInt32(UInt8(v1)) << 12)
                  | (UInt32(UInt8(v2)) << 6)
                  | UInt32(UInt8(v3))

            out.append(Byte((n >> 16) & 0xFF))
            if !pad2 { out.append(Byte((n >> 8) & 0xFF)) }
            if !pad3 { out.append(Byte(n & 0xFF)) }

            if (pad2 || pad3), idx + 4 != bytes.count { return nil }

            idx += 4
        }

        self.init(out)
    }
}
