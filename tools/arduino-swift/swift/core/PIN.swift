// PIN.swift
// High-level digital pin wrapper for Embedded Swift + Arduino Core.

public final class PIN {

    public let number: U32

    // Cache the last configured mode to avoid redundant pinMode calls.
    private var currentMode: Mode?

    // MARK: - Init

    public init(_ pin: Int) {
        self.number = U32(pin)
        self.currentMode = nil
    }

    private init(resolved pin: U32) {
        self.number = pin
        self.currentMode = nil
    }

    // Built-in LED
    public static let builtin = PIN(resolved: arduino_builtin_led())

    // MARK: - Mode

    public enum Mode {
        case input
        case output
        case inputPullup

        fileprivate var raw: U32 {
            switch self {
            case .input:       return arduino_mode_input()
            case .output:      return arduino_mode_output()
            case .inputPullup: return arduino_mode_input_pullup()
            }
        }
    }

    @inline(__always)
    private func ensureMode(_ mode: Mode) {
        if currentMode == nil || currentMode! != mode {
            arduino_pinMode(number, mode.raw)
            currentMode = mode
        }
    }

    // MARK: - Public API (Digital)

    public func input() {
        ensureMode(.input)
    }

    public func output() {
        ensureMode(.output)
    }

    public func pullup() {
        ensureMode(.inputPullup)
    }

    public func on() {
        ensureMode(.output)
        arduino_digitalWrite(number, arduino_high())
    }

    public func off() {
        ensureMode(.output)
        arduino_digitalWrite(number, arduino_low())
    }

    public func write(_ isOn: Bool) {
        isOn ? on() : off()
    }

    public func toggle() {
        ensureMode(.output)
        if readRaw() == arduino_high() {
            arduino_digitalWrite(number, arduino_low())
        } else {
            arduino_digitalWrite(number, arduino_high())
        }
    }

    // MARK: - Read

    public func readRaw() -> U32 {
        if currentMode == nil {
            ensureMode(.input)
        }
        return arduino_digitalRead(number)
    }

    public func isOn() -> Bool {
        readRaw() == arduino_high()
    }

    public func isOff() -> Bool {
        !isOn()
    }
}

// MARK: - Equatable support

extension PIN.Mode: Equatable {
    public static func == (lhs: PIN.Mode, rhs: PIN.Mode) -> Bool {
        switch (lhs, rhs) {
        case (.input, .input),
             (.output, .output),
             (.inputPullup, .inputPullup):
            return true
        default:
            return false
        }
    }
}