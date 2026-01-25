// App.swift — Due as I2C SLAVE (ASCII-only)
// Address: 0x12

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    Serial.begin(115200)
    Serial.print("Due SLAVE boot (addr 0x12)\n")

    let led = PIN.builtin
    led.off()

    // Prebuilt replies (ASCII only)
    var reply = asciiPacket("Idle")

    let dev = I2C.SlaveDevice(address: 0x12)

    dev.onReceive = { pkt in
        let b = pkt.bytes

        Serial.print("[I2C RX] bytes=")
        I2C.Print.hexBytes(b)
        Serial.print("\n")

        if asciiEquals(b, asciiBytes("LED_ON")) {
            led.on()
            reply = asciiPacket("Acendi o Led")
            Serial.print("-> LED ON\n")
        } else if asciiEquals(b, asciiBytes("LED_OFF")) {
            led.off()
            reply = asciiPacket("Apaguei o Led")
            Serial.print("-> LED OFF\n")
        } else {
            reply = asciiPacket("Cmd invalido")
            Serial.print("-> INVALID CMD\n")
        }
    }

    dev.onRequest = {
        reply
    }

    ArduinoRuntime.add(dev)
    ArduinoRuntime.keepAlive()
}