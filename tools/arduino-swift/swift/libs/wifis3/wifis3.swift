// wifis3.swift

public enum WiFiS3Status: I32, Sendable {
    case idle             = 0
    case noSSIDAvail      = 1
    case scanCompleted    = 2
    case connected        = 3
    case connectFailed    = 4
    case connectionLost   = 5
    case disconnected     = 6
    case noModule         = 255
}

public struct WiFiS3IP: Sendable {
    public let a: U8, b: U8, c: U8, d: U8
    public init(_ a: U8, _ b: U8, _ c: U8, _ d: U8) { self.a=a; self.b=b; self.c=c; self.d=d }

    public static func fromPacked(_ v: U32) -> WiFiS3IP {
        .init(
            U8((v >> 24) & 0xFF),
            U8((v >> 16) & 0xFF),
            U8((v >>  8) & 0xFF),
            U8((v >>  0) & 0xFF)
        )
    }

    public func toString() -> String { "\(a).\(b).\(c).\(d)" }
    public var isZero: Bool { a == 0 && b == 0 && c == 0 && d == 0 }
}

public struct WiFiS3Network: Sendable {
    public let ssid: String
    public let rssi: I32
    public let encryptionType: I32
}

public enum WiFiS3 {

    // Basic
    public static func status() -> WiFiS3Status {
        WiFiS3Status(rawValue: arduino_wifis3_status()) ?? .disconnected
    }

    public static func isAvailable() -> Bool { arduino_wifis3_isAvailable() == 1 }

    @discardableResult
    public static func disconnect() -> WiFiS3Status {
        _ = arduino_wifis3_disconnect()
        return status()
    }

    @discardableResult
    public static func begin(ssid: String, password: String) -> WiFiS3Status {
        let rc: I32 = ssid.withCString { s in
            password.withCString { p in
                arduino_wifis3_begin_ssid_pass(s, p)
            }
        }
        return WiFiS3Status(rawValue: rc) ?? status()
    }

    // Info
    public static func firmwareVersion() -> String {
        var buf = [CChar](repeating: 0, count: 64)
        let cap = U32(buf.count) // ✅ capture before borrowing
        buf.withUnsafeMutableBufferPointer { p in
            _ = arduino_wifis3_firmwareVersion(p.baseAddress, cap)
        }
        return String(cString: buf)
    }

    public static func currentSSID() -> String {
        var buf = [CChar](repeating: 0, count: 64)
        let cap = U32(buf.count) // ✅ capture before borrowing
        buf.withUnsafeMutableBufferPointer { p in
            _ = arduino_wifis3_ssid(p.baseAddress, cap)
        }
        return String(cString: buf)
    }

    public static func rssi() -> I32 { arduino_wifis3_rssi() }

    public static func localIP() -> WiFiS3IP { .fromPacked(arduino_wifis3_localIP_u32()) }

    /// UNO R4 WiFi: às vezes conecta e ainda está 0.0.0.0 por um tempo
    public static func waitLocalIP(timeoutMs: U32 = 15_000, pollMs: U32 = 100) -> WiFiS3IP {
        .fromPacked(arduino_wifis3_waitLocalIP_u32(timeoutMs, pollMs))
    }

    // Scan (opcional)
    public static func scanNetworks() -> [WiFiS3Network] {
        let count = arduino_wifis3_scanNetworks()
        if count <= 0 { return [] }

        var out: [WiFiS3Network] = []
        out.reserveCapacity(Int(count))

        for i in 0..<count {
            var ssidBuf = [CChar](repeating: 0, count: 64)
            let cap = U32(ssidBuf.count) // ✅ capture before borrowing
            ssidBuf.withUnsafeMutableBufferPointer { p in
                _ = arduino_wifis3_scan_ssid(i, p.baseAddress, cap)
            }

            let ssid = String(cString: ssidBuf)
            let rssi = arduino_wifis3_scan_rssi(i)
            let enc  = arduino_wifis3_scan_encryptionType(i)
            out.append(.init(ssid: ssid, rssi: rssi, encryptionType: enc))
        }

        arduino_wifis3_scanDelete() // no-op no C++
        return out
    }

    // IDE-like preflight
    public struct Preflight: Sendable {
        public let hasModule: Bool
        public let firmware: String
        public let status0: WiFiS3Status
    }

    public static func preflight() -> Preflight {
        let st = status()
        let fv = firmwareVersion()
        return .init(hasModule: st != .noModule, firmware: fv, status0: st)
    }

    /// Loop “igual IDE”: tenta begin e espera 10s
    public static func connectLoop(
        ssid: String,
        password: String,
        attemptDelayMs: U32 = 10_000,
        maxAttempts: Int = 0 // 0 = infinito
    ) -> Bool {

        let pf = preflight()
        if !pf.hasModule { return false }

        var attempts = 0
        var st = status()

        while st != .connected {
            println("Attempting to connect to SSID: \(ssid)")
            st = begin(ssid: ssid, password: password)

            attempts += 1
            if maxAttempts > 0 && attempts >= maxAttempts { return false }

            arduino_delay_ms(attemptDelayMs)
            st = status()
        }

        return true
    }
}

// ============================================================
// ArduinoTickable manager (recomendado)
// ============================================================

public final class WiFiS3Manager: ArduinoTickable {

    public enum Mode { case manual, keepConnected }

    public enum State: Sendable {
        case idle
        case connecting
        case connected(ip: WiFiS3IP)
        case failed(status: WiFiS3Status)
        case disconnected
    }

    private var mode: Mode = .manual
    private var ssid: String = ""
    private var password: String = ""

    private var attemptEveryMs: U32 = 10_000 // igual IDE

    private var onConnected: ((WiFiS3IP) -> Void)?
    private var onDisconnected: (() -> Void)?
    private var onFailed: ((WiFiS3Status) -> Void)?

    private var state: State = .idle
    private var lastStatus: WiFiS3Status = .disconnected
    private var nextAttemptAt: U32 = 0
    private var didPrintPreflight = false

    public init() {}

    public func setMode(_ mode: Mode) { self.mode = mode }

    public func configure(ssid: String, password: String, attemptEveryMs: U32 = 10_000) {
        self.ssid = ssid
        self.password = password
        self.attemptEveryMs = attemptEveryMs
    }

    public func setCallbacks(
        onConnected: ((WiFiS3IP) -> Void)? = nil,
        onDisconnected: (() -> Void)? = nil,
        onFailed: ((WiFiS3Status) -> Void)? = nil
    ) {
        self.onConnected = onConnected
        self.onDisconnected = onDisconnected
        self.onFailed = onFailed
    }

    public func connectNow() {
        nextAttemptAt = arduino_millis()
        state = .connecting
    }

    public func tick() {
        let now = arduino_millis()

        if !didPrintPreflight {
            didPrintPreflight = true
            let pf = WiFiS3.preflight()
            println("=== WiFiS3 (UNO R4 WiFi) ===")
            println("WiFiS3.isAvailable(): \(WiFiS3.isAvailable() ? "YES" : "NO")")
            println("WiFi firmwareVersion: '\(pf.firmware)'")
            println("WiFi status0: \(pf.status0.rawValue)")
            if !pf.hasModule {
                println("Communication with WiFi module failed!")
                state = .failed(status: .noModule)
                onFailed?(.noModule)
                return
            }
        }

        let st = WiFiS3.status()

        // Connected edge
        if st == .connected && lastStatus != .connected {
            let ip = WiFiS3.waitLocalIP(timeoutMs: 15_000, pollMs: 100)
            state = .connected(ip: ip)
            onConnected?(ip)
        }

        // Disconnected edge
        if st != .connected && lastStatus == .connected {
            state = .disconnected
            onDisconnected?()
            if mode == .keepConnected {
                nextAttemptAt = now &+ attemptEveryMs
            }
        }

        switch state {
        case .idle:
            break

        case .connecting:
            if now >= nextAttemptAt && !ssid.isEmpty {
                println("Attempting to connect to SSID: \(ssid)")
                _ = WiFiS3.begin(ssid: ssid, password: password)
                nextAttemptAt = now &+ attemptEveryMs
            }

        case .disconnected:
            if mode == .keepConnected, now >= nextAttemptAt {
                state = .connecting
                nextAttemptAt = now
            }

        case .failed(let s):
            if mode == .keepConnected, s != .noModule, now >= nextAttemptAt {
                state = .connecting
                nextAttemptAt = now
            }

        case .connected:
            break
        }

        lastStatus = st
    }
}