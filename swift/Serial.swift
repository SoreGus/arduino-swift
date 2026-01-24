// Serial.swift
// Tiny Serial wrapper for Arduino Serial.
// Only `print`. Use `print("\n")` if you want newline.

public enum Serial {
    @inline(__always)
    public static func begin(_ baud: U32) {
        arduino_serial_begin(baud)
    }

    // MARK: - print overloads

    @inline(__always)
    public static func print(_ s: StaticString) {
        // Convert StaticString to a C string.
        // This assumes the StaticString is null-terminated, which is true for string literals.
        s.withUTF8Buffer { buf in
            // Ensure we have a trailing 0; if not, we fallback to byte-by-byte.
            if buf.count > 0 && buf[buf.count - 1] == 0 {
                buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buf.count) { cstr in
                    arduino_serial_print_cstr(cstr)
                }
            } else {
                // Rare path: emit bytes manually by building a temporary C string.
                // (Keep it simple and safe.)
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
        // For Embedded Swift, avoid heavy formatting:
        // convert to UTF8 + null terminate.
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
}