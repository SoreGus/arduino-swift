// SSD1306.swift
// High-level Swift API for SSD1306 via ArduinoSwift
// SAFE: no heap allocation required by this file

public struct SSD1306 {

    // MARK: - Init

    @inline(__always)
    public static func begin(i2cAddress: UInt8 = 0x3C) {
        arduino_ssd1306_begin(i2cAddress)
        arduino_ssd1306_set_font_system5x7()
        arduino_ssd1306_clear()
    }

    // MARK: - Screen control

    @inline(__always)
    public static func clear() {
        arduino_ssd1306_clear()
    }

    @inline(__always)
    public static func setCursor(col: UInt8, row: UInt8) {
        arduino_ssd1306_set_cursor(col, row)
    }

    // MARK: - Printing

    /// Print a static string (NO interpolation)
    @inline(__always)
    public static func print(_ text: StaticString) {
        text.withUTF8Buffer {
            arduino_ssd1306_print_cstr(
                $0.baseAddress!.withMemoryRebound(
                    to: CChar.self,
                    capacity: $0.count
                ) { $0 }
            )
        }
    }

    /// Print a null-terminated C string buffer
    @inline(__always)
    public static func printCStr(_ ptr: UnsafePointer<CChar>) {
        arduino_ssd1306_print_cstr(ptr)
    }
}