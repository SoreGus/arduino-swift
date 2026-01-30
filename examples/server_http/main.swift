//
//  main.swift
//  ArduinoSwift - UNO R4 WiFi (WiFiS3 + HTTP Server)
//
//  This file is the firmware entrypoint used by the ArduinoSwift toolchain.
//
//  The build system exports `arduino_swift_main()` as the main sketch logic,
//  while the official Arduino core remains responsible for initialization,
//  linking, uploading, and board-specific startup.
//
//  What this example does:
//  - Boots and configures the builtin LED pin.
//  - Prints basic WiFi diagnostics (availability, firmware version, status).
//  - Connects to an access point using an Arduino-IDE-like retry loop.
//  - Starts a cooperative HTTP server integrated via ArduinoRuntime (tick-based).
//  - Registers GET/POST routes including a small JSON response.
//  - Keeps the runtime alive with a simple delay loop.
//
//  Notes:
//  - This example assumes wifis3 and http_server libraries are enabled in config.json.
//  - The HTTP server runs via ArduinoTickable and must be added to ArduinoRuntime.
//  - Avoid heavy string/unicode operations; prefer small ASCII routes/headers.
//

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

    let ok = WiFiS3.connectLoop(
        ssid: "SORE",
        password: "vStmtv!1",
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

    let server = HTTPServer()

    server.onFailure { err in
        println("Failure in Server")
        println(err.message)
    }

    server.get("/value") { _ in
        .response("hello\n", status: 200, contentType: "text/plain; charset=utf-8")
    }

    server.post("/echo") { req in
        .response(req.body, status: 200, contentType: "application/octet-stream")
    }

    server.post("/json") { _ in
        .json(
            .object([
                ("ok", .bool(true)),
                ("value", .number(123)),
                ("msg", .string("hello"))
            ])
        )
    }

    _ = server.start(port: 80)
    ArduinoRuntime.add(server)

    ArduinoRuntime.keepAlive {
        delay(1000)
    }
}