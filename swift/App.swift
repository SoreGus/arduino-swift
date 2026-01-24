@_cdecl("arduino_swift_main")
public func arduino_swift_main() -> Void {
    Serial.begin(115200)
    Serial.print("Boot OK\n")

    let led = PIN.builtin
    led.off()
    Serial.print("LED ready\n")

    let button = Button(
        5,
        onPress: {
            led.toggle()
            Serial.print("-------pressed\n")
        },
        onRelease: {
            Serial.print("-------released\n")
        }
    )

    ArduinoRuntime.add(button)

    Serial.print("runtime on\n")
    //ArduinoRuntime.keepAlive()
    ArduinoRuntime.keepAlive {
        ArduinoRuntime.delay(ms: 500)
        Serial.print("test\n")
    }
}