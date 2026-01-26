// main.swift
// Minimal example:
// Button on pin 5 toggles the builtin LED

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    Serial.begin(115200)
    Serial.print("Swift main boot\n")

    let led = PIN.builtin
    led.output()
    led.off()

    let button = Button(
        5,
        onPress: {
            led.toggle()
            Serial.print("Button pressed -> LED toggled\n")
        }
    )

    ArduinoRuntime.add(button)
    while true {
        delay(5000)
        Serial.print("Hello\n")
    }
}