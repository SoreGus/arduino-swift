// Serial.swift
// Tiny Serial wrapper for Arduino Serial (Embedded Swift friendly).
//
// Features:
// - print overloads for StaticString / String / numbers
// - println sugar
// - printHex2 for byte dumps (00..FF)
// - write(byte) for raw printable bytes (like your old Serial.write)

public enum Serial {

    // MARK: - Begin

    @inline(__always)
    public static func begin(_ baud: U32) {
        arduino_serial_begin(baud)
    }

    // MARK: - print overloads

    @inline(__always)
    public static func print(_ s: StaticString) {
        // Convert StaticString to a C string.
        // Assumes string literals are null-terminated (usually true).
        s.withUTF8Buffer { buf in
            if buf.count > 0 && buf[buf.count - 1] == 0 {
                buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buf.count) { cstr in
                    arduino_serial_print_cstr(cstr)
                }
            } else {
                // Fallback: build a null-terminated temp buffer.
                var tmp = [UInt8](buf)
                tmp.append(0)
                tmp.withUnsafeBufferPointer { tb in
                    tb.baseAddress!.withMemoryRebound(to: CChar.self, capacity: tb.count) { cstr in
                        arduino_serial_print_cstr(cstr)
                    }
                }
            }
        }
    }

    @inline(__always)
    public static func print(_ s: String) {
        // Embedded Swift: keep it simple -> UTF8 + null terminator.
        var bytes = Array(s.utf8)
        bytes.append(0)
        bytes.withUnsafeBufferPointer { b in
            b.baseAddress!.withMemoryRebound(to: CChar.self, capacity: b.count) { cstr in
                arduino_serial_print_cstr(cstr)
            }
        }
    }

    @inline(__always)
    public static func print(_ v: Int) {
        arduino_serial_print_i32(I32(v))
    }

    @inline(__always)
    public static func print(_ v: Int32) {
        arduino_serial_print_i32(v)
    }

    @inline(__always)
    public static func print(_ v: UInt32) {
        arduino_serial_print_u32(v)
    }

    @inline(__always)
    public static func print(_ v: Double) {
        arduino_serial_print_f64(v)
    }

    @inline(__always)
    public static func print(_ v: Float) {
        arduino_serial_print_f64(Double(v))
    }

    public static func printHexBytes(_ bytes: [UInt8]) {
        for b in bytes {
            printHex2(b)
            print(" ")
        }
    }

    public static func printASCIIOrHex(_ bytes: [UInt8]) {
        for b in bytes {
            if b >= 0x20 && b <= 0x7E {
                write(b)
            } else {
                printHex2(b)
                print(" ")
            }
        }
    }

    // MARK: - println sugar

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

    // MARK: - Raw byte write (best-effort)

    /// Writes a single byte as a 1-char C string.
    /// Good for printable ASCII. For non-printable, use printHex2.
    @inline(__always)
    public static func write(_ b: UInt8) {
        var s: [UInt8] = [b, 0]
        s.withUnsafeBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: 2) { cstr in
                arduino_serial_print_cstr(cstr)
            }
        }
    }

    // MARK: - Hex helpers

    /// Prints a byte as two hex digits: 00..FF
    @inline(__always)
    public static func printHex2(_ b: UInt8) {
        let hi = nibbleHex(b >> 4)
        let lo = nibbleHex(b)
        var s: [UInt8] = [hi, lo, 0]
        s.withUnsafeBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: 3) { cstr in
                arduino_serial_print_cstr(cstr)
            }
        }
    }

    @inline(__always)
    private static func nibbleHex(_ v: UInt8) -> UInt8 {
        let x = v & 0x0F
        return x < 10 ? (UInt8(ascii: "0") + x) : (UInt8(ascii: "A") + (x - 10))
    }
}