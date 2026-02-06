public struct Data {
    private var storage: [UInt8]

    public init() {
        self.storage = []
    }

    public init(_ bytes: [UInt8]) {
        self.storage = bytes
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }

    @inline(__always)
    public mutating func append(_ byte: UInt8) {
        storage.append(byte)
    }

    @inline(__always)
    public mutating func append(contentsOf bytes: [UInt8]) {
        storage.append(contentsOf: bytes)
    }

    @inline(__always)
    public mutating func append(_ value: UInt16, endian: Endianness) {
        let v = value
        switch endian {
        case .little:
            storage.append(UInt8(truncatingIfNeeded: v & 0x00FF))
            storage.append(UInt8(truncatingIfNeeded: (v >> 8) & 0x00FF))
        case .big:
            storage.append(UInt8(truncatingIfNeeded: (v >> 8) & 0x00FF))
            storage.append(UInt8(truncatingIfNeeded: v & 0x00FF))
        }
    }

    @inline(__always)
    public func toArray() -> [UInt8] { storage }

    @inline(__always)
    public subscript(index: Int) -> UInt8 {
        get { storage[index] }
        set { storage[index] = newValue }
    }

    @inline(__always)
    public func slice(from: Int, count: Int) -> [UInt8] {
        if from < 0 || count < 0 || from >= storage.count { return [] }
        let end = Swift.min(storage.count, from + count)
        if end <= from { return [] }
        return Array(storage[from..<end])
    }

    @inline(__always)
    public func readUInt8(at index: Int) -> UInt8 {
        if index < 0 || index >= storage.count { return 0 }
        return storage[index]
    }

    @inline(__always)
    public func readUInt16(at index: Int, endian: Endianness) -> UInt16 {
        if index < 0 || index + 1 >= storage.count { return 0 }
        let a = UInt16(storage[index])
        let b = UInt16(storage[index + 1])
        switch endian {
        case .little: return a | (b << 8)
        case .big:    return (a << 8) | b
        }
    }

    // ASCII-only, avoids Unicode normalization paths in Embedded Swift.
    @inline(__always)
    public func utf8StringLossyASCII() -> String {
        if storage.isEmpty { return "" }
        var out = String()
        out.reserveCapacity(storage.count)
        var i = 0
        while i < storage.count {
            let b = storage[i]
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
