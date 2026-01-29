// main.swift
// ArduinoSwift – GIGA R1 WiFi STA monitor (raw ip version)
//
// - connect to WiFi
// - print ssid + ip (raw) + rssi every 3000ms
// - no time math
// - no early return (use if/else)
// - keepAlive already loops internally

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {

    let ssid = "Sore"
    let pass = "atendimento12"

    print("swift boot\n")
    print("wifi: sta begin\n")

    _ = wifi.staBegin(ssid: ssid, pass: pass)

    ArduinoRuntime.keepAlive {

        let st = wifi.getStatus()

        if st.isConnected {

            print("wifi: connected\n")

            // ssid (String) still optional: OK to test; if you suspect String, comment this line.
            let name = wifi.ssid() ?? "-"

            // raw ip (no String allocation inside wifi)
            let ip = wifi.localIpString()

            let rssi = wifi.rssi()

            print("ssid: ")
            println(name)

            print("ip: ")
            println(ip)

            print("rssi: ")
            print(rssi)
            print(" dBm\n\n")

            delay(3000)

        } else {

            print("wifi: status=")
            print(st.name)
            print(" (")
            print(st.rawValue)
            print(")\n")

            delay(1000)
        }
    }
}