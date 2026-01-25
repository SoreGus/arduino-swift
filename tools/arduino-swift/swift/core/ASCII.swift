// ASCII.swift — tiny ASCII helpers (Embedded-safe)

@inline(__always)
public func asciiBytes(_ s: StaticString) -> [UInt8] {
    var out: [UInt8] = []
    out.reserveCapacity(s.utf8CodeUnitCount)
    let p = s.utf8Start
    for i in 0..<s.utf8CodeUnitCount {
        out.append(p[i])
    }
    return out
}

@inline(__always)
public func asciiEquals(_ a: [UInt8], _ b: [UInt8]) -> Bool {
    if a.count != b.count { return false }
    var i = 0
    while i < a.count {
        if a[i] != b[i] { return false }
        i &+= 1
    }
    return true
}

/// Build an I2C.Packet from ASCII bytes using Packet's unlabeled initializer.
@inline(__always)
public func asciiPacket(_ s: StaticString) -> I2C.Packet {
    I2C.Packet(asciiBytes(s))
}