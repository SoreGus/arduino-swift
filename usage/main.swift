@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    println("Swift main boot")

    let led = PIN.builtin
    led.output()
    led.off()

    println("=== WiFiS3 (UNO R4 WiFi) ===")
    println("WiFiS3.isAvailable(): \(WiFiS3.isAvailable() ? "YES" : "NO")")
    println("WiFi firmwareVersion: '\(WiFiS3.firmwareVersion())'")
    println("WiFi status0: \(WiFiS3.status().rawValue)")

    // Conecta como no exemplo (loop com delay)
    let ok = WiFiS3.connectLoop(
        ssid: "*",
        password: "*",
        attemptDelayMs: 10_000,
        maxAttempts: 0
    )

    if ok {
        let ip = WiFiS3.localIP()
        led.on()
        println("WiFi connected. IP: \(ip.toString())")
        println("SSID: \(WiFiS3.currentSSID())")
        println("signal strength (RSSI): \(WiFiS3.rssi()) dBm")
    } else {
        led.off()
        println("WiFi connect failed.")
    }

    // --- HTTP Server ---
   let server = HTTPServer()

    server.onFailure { err in
        println("Failure in Server")
        println(err.message)
    }

    server.get("/value") { _ in
        .text("hello\n", status: 200, contentType: "text/plain; charset=utf-8")
    }

    server.post("/echo") { req in
        .data(req.body, status: 200, contentType: "application/octet-stream")
    }

    _ = server.start(port: 80)
    ArduinoRuntime.add(server)   // <-- do jeito que você quer

    ArduinoRuntime.keepAlive {
        delay(1000)
    }
}