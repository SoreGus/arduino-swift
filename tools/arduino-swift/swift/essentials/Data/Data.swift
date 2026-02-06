public struct Data: Equatable, Hashable, Sendable {
    @usableFromInline
    internal var storage: [Byte]

    public init() {
        self.storage = []
    }

    public init(_ bytes: [Byte]) {
        self.storage = bytes
    }

    public init<S: Sequence>(_ bytes: S) where S.Element == Byte {
        self.storage = Array(bytes)
    }

    public var count: ByteCount { storage.count }
    public var isEmpty: Bool { storage.isEmpty }

    public subscript(index: ByteCount) -> Byte {
        get { storage[index] }
        set { storage[index] = newValue }
    }

    public func toArray() -> [Byte] { storage }

    public mutating func append(_ byte: Byte) {
        storage.append(byte)
    }

    public mutating func append(contentsOf bytes: [Byte]) {
        storage.append(contentsOf: bytes)
    }

    public mutating func append<S: Sequence>(contentsOf bytes: S) where S.Element == Byte {
        storage.append(contentsOf: bytes)
    }

    public mutating func append(_ value: UInt16, endian: Endian = .little) {
        switch endian {
        case .little:
            storage.append(Byte(truncatingIfNeeded: value & 0x00FF))
            storage.append(Byte(truncatingIfNeeded: (value >> 8) & 0x00FF))
        case .big:
            storage.append(Byte(truncatingIfNeeded: (value >> 8) & 0x00FF))
            storage.append(Byte(truncatingIfNeeded: value & 0x00FF))
        }
    }

    public mutating func append(_ value: UInt32, endian: Endian = .little) {
        switch endian {
        case .little:
            storage.append(Byte(truncatingIfNeeded: (value >> 0) & 0xFF))
            storage.append(Byte(truncatingIfNeeded: (value >> 8) & 0xFF))
            storage.append(Byte(truncatingIfNeeded: (value >> 16) & 0xFF))
            storage.append(Byte(truncatingIfNeeded: (value >> 24) & 0xFF))
        case .big:
            storage.append(Byte(truncatingIfNeeded: (value >> 24) & 0xFF))
            storage.append(Byte(truncatingIfNeeded: (value >> 16) & 0xFF))
            storage.append(Byte(truncatingIfNeeded: (value >> 8) & 0xFF))
            storage.append(Byte(truncatingIfNeeded: (value >> 0) & 0xFF))
        }
    }

    public func readUInt8(at index: ByteCount) -> UInt8? {
        guard index >= 0, index < storage.count else { return nil }
        return storage[index]
    }

    public func readUInt16(at index: ByteCount, endian: Endian = .little) -> UInt16? {
        guard index >= 0, index + 1 < storage.count else { return nil }
        let b0 = UInt16(storage[index])
        let b1 = UInt16(storage[index + 1])
        switch endian {
        case .little: return b0 | (b1 << 8)
        case .big: return (b0 << 8) | b1
        }
    }

    public func readUInt32(at index: ByteCount, endian: Endian = .little) -> UInt32? {
        guard index >= 0, index + 3 < storage.count else { return nil }
        let b0 = UInt32(storage[index + 0])
        let b1 = UInt32(storage[index + 1])
        let b2 = UInt32(storage[index + 2])
        let b3 = UInt32(storage[index + 3])
        switch endian {
        case .little:
            return (b0 << 0) | (b1 << 8) | (b2 << 16) | (b3 << 24)
        case .big:
            return (b0 << 24) | (b1 << 16) | (b2 << 8) | (b3 << 0)
        }
    }

    public func slice(from start: ByteCount, count: ByteCount) -> Data? {
        guard start >= 0, count >= 0, start + count <= storage.count else { return nil }
        return Data(storage[start..<(start + count)])
    }

    public func hexString(uppercase: Bool = true, separator: String = " ") -> String {
        let table = uppercase ? Array("0123456789ABCDEF".utf8) : Array("0123456789abcdef".utf8)
        var out: [Byte] = []
        out.reserveCapacity(max(0, storage.count * 3 - 1))
        for i in 0..<storage.count {
            let b = storage[i]
            out.append(table[Int((b >> 4) & 0x0F)])
            out.append(table[Int(b & 0x0F)])
            if i + 1 < storage.count, !separator.isEmpty {
                out.append(contentsOf: separator.utf8)
            }
        }
        return String(decoding: out, as: UTF8.self)
    }
}
