// Button.swift
// Button built on PIN with press + release callbacks.
// Uses polling (no interrupts) and integrates with ArduinoRuntime.
//
// Usage:
//   let button = Button(
//       5,
//       onPress: { ... },
//       onRelease: { ... }
//   )
//   ArduinoRuntime.add(button)

public final class Button: ArduinoTickable {

    // MARK: - Mode

    public enum Mode {
        case normal   // pressed == HIGH
        case pullup   // pressed == LOW (default)
    }

    // MARK: - Public

    public let pin: PIN

    // MARK: - Callbacks

    private var onPressBlock: (() -> Void)?
    private var onReleaseBlock: (() -> Void)?

    // MARK: - State

    private var enabled: Bool = true
    private var mode: Mode = .pullup

    private var didInitState = false
    private var lastPressed = false

    private var debounceMs: U32 = 25
    private var lastEdgeMs: U32 = 0

    // MARK: - Init

    public init(
        _ pinNumber: Int,
        onPress: (() -> Void)? = nil,
        onRelease: (() -> Void)? = nil
    ) {
        self.pin = PIN(pinNumber)
        self.onPressBlock = onPress
        self.onReleaseBlock = onRelease
        configureHardware()
    }

    // MARK: - Enable / Disable

    public func enable() {
        enabled = true
        didInitState = false
    }

    public func disable() {
        enabled = false
    }

    public func isEnabled() -> Bool {
        enabled
    }

    // MARK: - Mode

    public func pullup() {
        mode = .pullup
        configureHardware()
    }

    public func normalInput() {
        mode = .normal
        configureHardware()
    }

    // MARK: - Debounce

    public func setDebounce(ms: U32) {
        debounceMs = ms
    }

    // MARK: - State query (requested)

    /// Returns true while button is physically pressed
    public func isOn() -> Bool {
        readPressed()
    }

    // MARK: - Runtime hook

    public func addToRuntime() {
        ArduinoRuntime.add(self)
    }

    // MARK: - Tick (called by runtime)

    public func tick() {
        guard enabled else { return }

        let now = arduino_millis()
        let pressed = readPressed()

        if !didInitState {
            lastPressed = pressed
            didInitState = true
            return
        }

        if pressed != lastPressed {
            let dt = now &- lastEdgeMs
            if dt >= debounceMs {
                lastEdgeMs = now

                if pressed {
                    onPressBlock?()
                } else {
                    onReleaseBlock?()
                }
            }
        }

        lastPressed = pressed
    }

    // MARK: - Internals

    private func configureHardware() {
        switch mode {
        case .pullup:
            pin.pullup()
        case .normal:
            pin.input()
        }
        didInitState = false
    }

    private func readPressed() -> Bool {
        switch mode {
        case .pullup:
            return pin.readRaw() == arduino_low()
        case .normal:
            return pin.readRaw() == arduino_high()
        }
    }
}