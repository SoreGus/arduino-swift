// main.swift
// Minimal example:
// Button on pin 5 toggles the builtin LED

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    print("Swift main boot\n")

    let led = PIN.builtin
    led.output()
    led.off()

    let button = Button(
        pinNumber: 5,
        onPress: {
            led.toggle()
            print("Button pressed -> LED toggled\n")
        }
    )

    ArduinoRuntime.add(button)
    ArduinoRuntime.keepAlive()
}