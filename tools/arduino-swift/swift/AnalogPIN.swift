// AnalogPIN.swift
// High-level analog pin wrapper for Embedded Swift + Arduino Core.

public final class AnalogPIN {
    public let number: U32

    // Configure analog resolution once (Due: 12-bit recommended).
    private static var configured: Bool = false
    private static var maxValueCache: U32 = 1023

    public init(_ number: U32, resolutionBits: U32 = 12) {
        self.number = number
        AnalogPIN.ensureConfigured(resolutionBits: resolutionBits)
    }

    private static func ensureConfigured(resolutionBits: U32) {
        if configured { return }
        configured = true

        // For Due/SAM this will set ADC resolution.
        arduino_analogReadResolution(resolutionBits)
        maxValueCache = arduino_analogMaxValue()
    }

    public func value() -> U32 {
        return arduino_analogRead(number)
    }

    public func maxValue() -> U32 {
        return AnalogPIN.maxValueCache
    }

    /// Returns a normalized value in [0.0, 1.0].
    /// Uses Double because it's usually safer across Embedded Swift toolchains.
    public func normalized() -> Double {
        let v = Double(value())
        let m = Double(maxValue())
        if m <= 0 { return 0.0 }
        let n = v / m
        if n < 0.0 { return 0.0 }
        if n > 1.0 { return 1.0 }
        return n
    }
}