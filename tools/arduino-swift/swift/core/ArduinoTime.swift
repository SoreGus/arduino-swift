// ============================================================
// File: swift/core/ArduinoTime.swift
// ArduinoSwift - time helper
//
// Provides ArduinoTime.millis() without requiring Foundation.
// Expects a C symbol `millis()` from Arduino core.
// ============================================================

public enum ArduinoTime {
    @inline(__always)
    public static func millis() -> U32 {
        _millis()
    }
}

// Arduino core provides `unsigned long millis(void);`
@_silgen_name("millis")
private func _millis() -> U32
