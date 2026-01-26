// Print.swift
// Global print helpers with auto-Serial initialization

@inline(__always)
private func _ensureSerial() {
    if !Serial.isInitialized() {
        Serial.begin(115200)
    }
}

// MARK: - print

@inline(__always)
public func print(_ s: StaticString) {
    _ensureSerial()
    Serial.print(s)
}

@inline(__always)
public func print(_ s: String) {
    _ensureSerial()
    Serial.print(s)
}

@inline(__always)
public func print(_ v: Int) {
    _ensureSerial()
    Serial.print(v)
}

@inline(__always)
public func print(_ v: Int32) {
    _ensureSerial()
    Serial.print(v)
}

@inline(__always)
public func print(_ v: UInt32) {
    _ensureSerial()
    Serial.print(v)
}

@inline(__always)
public func print(_ v: Double) {
    _ensureSerial()
    Serial.print(v)
}

@inline(__always)
public func print(_ v: Float) {
    _ensureSerial()
    Serial.print(v)
}

// MARK: - println

@inline(__always)
public func println() {
    _ensureSerial()
    Serial.println()
}

@inline(__always)
public func println(_ s: StaticString) {
    _ensureSerial()
    Serial.println(s)
}

@inline(__always)
public func println(_ s: String) {
    _ensureSerial()
    Serial.println(s)
}

@inline(__always)
public func println(_ v: Int) {
    _ensureSerial()
    Serial.println(v)
}

@inline(__always)
public func println(_ v: Int32) {
    _ensureSerial()
    Serial.println(v)
}

@inline(__always)
public func println(_ v: UInt32) {
    _ensureSerial()
    Serial.println(v)
}

@inline(__always)
public func println(_ v: Double) {
    _ensureSerial()
    Serial.println(v)
}

@inline(__always)
public func println(_ v: Float) {
    _ensureSerial()
    Serial.println(v)
}

// MARK: - Raw byte

@inline(__always)
public func write(_ b: UInt8) {
    _ensureSerial()
    Serial.write(b)
}

// MARK: - Hex helpers

@inline(__always)
public func printHex2(_ b: UInt8) {
    _ensureSerial()
    Serial.printHex2(b)
}

@inline(__always)
public func printHexBytes(_ bytes: [UInt8]) {
    _ensureSerial()
    Serial.printHexBytes(bytes)
}

@inline(__always)
public func printASCIIOrHex(_ bytes: [UInt8]) {
    _ensureSerial()
    Serial.printASCIIOrHex(bytes)
}