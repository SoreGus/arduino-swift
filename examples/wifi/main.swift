// main.swift

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    print("swift boot\n")

    let w = WiFiSTA(ssid: "Sore", pass: "atendimento12")
        .onConnect { info in
            print("wifi: connected\n")
            print("ssid: "); println(info.ssid)
            print("ip: "); println(info.ip)
            print("rssi: "); println(info.rssi); print(" dBm\n")
        }
        .onDisconnect { raw in
            print("wifi: disconnected status=")
            println(raw)
        }
        .onReport(everyMs: 3000) { info in
            println("onReportn")
            print("rssi: "); println(info.rssi); print(" dBm\n")
        }

    // Both are valid:
    // w.addToRuntime()
    ArduinoRuntime.add(w)

    ArduinoRuntime.keepAlive()
}