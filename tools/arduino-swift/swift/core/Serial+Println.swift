// Serial+Println.swift
// Adds println() convenience on top of Serial.print(...) implemented in Serial.swift.

extension Serial {

    @inline(__always)
    public static func println() {
        print("\n")
    }

    @inline(__always)
    public static func println(_ s: StaticString) {
        print(s); print("\n")
    }

    @inline(__always)
    public static func println(_ s: String) {
        print(s); print("\n")
    }

    @inline(__always)
    public static func println(_ v: Int) {
        print(v); print("\n")
    }

    @inline(__always)
    public static func println(_ v: Int32) {
        print(v); print("\n")
    }

    @inline(__always)
    public static func println(_ v: UInt32) {
        print(v); print("\n")
    }

    @inline(__always)
    public static func println(_ v: Double) {
        print(v); print("\n")
    }

    @inline(__always)
    public static func println(_ v: Float) {
        print(v); print("\n")
    }
}
