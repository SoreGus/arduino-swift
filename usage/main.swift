@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    print("Swift main boot\n")

    let led = PIN.builtin
    led.output()
    led.off()

    let wifi = WiFiS3Manager()
    wifi.configure(ssid: "SORE", password: "vStmtv!1", attemptEveryMs: 10_000)
    wifi.setMode(.keepConnected)
    wifi.setCallbacks(
        onConnected: { ip in
            println("WiFi connected. IP: \(ip.toString())")
            led.on()
            println("SSID: \(WiFiS3.currentSSID())")
            println("signal strength (RSSI): \(WiFiS3.rssi()) dBm")
        },
        onDisconnected: {
            println("WiFi disconnected")
            led.off()
        },
        onFailed: { st in
            println("WiFi failed: \(st.rawValue)")
            led.off()
        }
    )

    wifi.connectNow()
    ArduinoRuntime.add(wifi)

    ArduinoRuntime.keepAlive {
        delay(3000)
        println("Ping")
    }
}