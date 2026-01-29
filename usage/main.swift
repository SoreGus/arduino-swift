// ============================================================
// File: usage/main.swift
// ArduinoSwift - HTTP Server demo (GIGA R1 WiFi)
//
// - WiFiSTA tick connects and reports.
// - HTTPServer tick accepts 1 client per tick.
// - ArduinoRuntime.keepAlive() is the loop.
// ============================================================

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {

    delay(10000)

    print("swift boot\n")

    let server = HTTPServer(port: 80)
        .get("/value") { req in
            // Build "/path?query" as String (println does not accept [U8])
            var target: [U8] = req.pathBytes
            if !req.queryBytes.isEmpty {
                target.append(63) // '?'
                target.append(contentsOf: req.queryBytes)
            }

            let urlStr = String(decoding: target, as: UTF8.self)
            print("req url: "); println(urlStr)

            return HTTPResponse.okText("hello from swift server")
        }
        .post("/send") { req in
            let form = FormURLEncoded(req.body)
            if let v = form.value("key") {
                print("key: "); println(v)
            }

            // This overload expects contentType as String
            return HTTPResponse.status(200, "text/plain", "we got the message")
        }
        .onError { msg in
            print("server err: "); println(msg)
        }

    print("Checkpoint 0\n")

    let w = WiFiSTA(ssid: "Sore", pass: "atendimento12")
        .onConnect { info in
            println("wifi: connected")
            print("ssid: "); println(info.ssid)
            print("ip: "); println(info.ip)

            // Start server only after STA is ready
            _ = server.begin()
        }
        .onDisconnect { raw in
            print("wifi: disconnected status="); println(raw)
        }
        .onReport(everyMs: 3000) { info in
            println("")
            println("wifi: connected")
            print("ssid: "); println(info.ssid)
            print("ip: "); println(info.ip)
            print("rssi: "); println(info.rssi); print(" dBm\n")
        }

    print("Checkpoint 1\n")

    ArduinoRuntime.add(server)
    ArduinoRuntime.add(w)

    print("Checkpoint 2\n")

    ArduinoRuntime.keepAlive()
}