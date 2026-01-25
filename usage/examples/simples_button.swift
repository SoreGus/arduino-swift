// main.swift
// Minimal example:
// Button on pin 5 toggles the builtin LED

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    // Serial only for debug (optional)
    Serial.begin(115200)
    Serial.print("Swift main boot\n")

    // Builtin LED
    let led = PIN.builtin
    led.output()
    led.off()

    // Button on pin 5 (pullup by default)
    let button = Button(
        5,
        onPress: {
            led.toggle()
            Serial.print("Button pressed -> LED toggled\n")
        }
    )

    // Add button to runtime
    ArduinoRuntime.add(button)

    // Keep runtime alive
    ArduinoRuntime.keepAlive()
}