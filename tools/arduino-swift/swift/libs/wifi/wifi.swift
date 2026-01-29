// wifi.swift
// High-level Swift WiFi wrapper for ArduinoSwift ABI (GIGA R1 WiFi)
//
// Design goals:
// - Defensive: never force-unwrap, never assume UTF-8 validity.
// - Predictable: fixed small buffers; minimal temporary allocations.
// - Ergonomic: Optional String for values that may be unavailable.
//
// Notes:
// - The C ABI writers return number of bytes written (excluding the null terminator).
// - If n == 0, treat as "not available".

public enum wifi {

    // ------------------------------------------------------------
    // MARK: - Status
    // ------------------------------------------------------------

    public struct status: RawRepresentable, Equatable, Sendable {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }

        public static let idle           = status(rawValue: 0)
        public static let noSsidAvail    = status(rawValue: 1)
        public static let scanCompleted  = status(rawValue: 2)
        public static let connected      = status(rawValue: 3)
        public static let connectFailed  = status(rawValue: 4)
        public static let connectionLost = status(rawValue: 5)
        public static let disconnected   = status(rawValue: 6)

        public var isConnected: Bool { rawValue == Self.connected.rawValue }

        public var name: StaticString {
            switch rawValue {
            case 0: return "idle"
            case 1: return "noSsidAvail"
            case 2: return "scanCompleted"
            case 3: return "connected"
            case 4: return "connectFailed"
            case 5: return "connectionLost"
            case 6: return "disconnected"
            default: return "unknown"
            }
        }
    }

    public struct ip4: Sendable {
        public let a: U8
        public let b: U8
        public let c: U8
        public let d: U8
    }

    // ------------------------------------------------------------
    // MARK: - C-string helpers (defensive)
    // ------------------------------------------------------------

    /// Create a temporary null-terminated UTF-8 buffer for C APIs.
    /// This does allocate, but it's bounded by string length + 1.
    @inline(__always)
    private static func withCStringBytes<R>(_ s: String, _ body: (UnsafePointer<UInt8>) -> R) -> R {
        var utf8 = Array(s.utf8)
        utf8.append(0)
        return utf8.withUnsafeBufferPointer { buf in
            // baseAddress is non-nil because we appended one element
            body(buf.baseAddress!)
        }
    }

    /// Read bytes from a C ABI "writer" into a fixed buffer and decode as UTF-8.
    /// - Returns nil if:
    ///   - writer writes 0 bytes
    ///   - writer returns a length that doesn't fit the buffer
    ///   - bytes are not valid UTF-8
    @inline(__always)
    private static func readCString(
        cap: Int = 64,
        _ writer: (UnsafeMutablePointer<UInt8>, UInt32) -> UInt32
    ) -> String? {
        if cap <= 1 { return nil }

        var buf = [UInt8](repeating: 0, count: cap)
        let n: UInt32 = buf.withUnsafeMutableBufferPointer { p in
            writer(p.baseAddress!, UInt32(p.count))
        }

        if n == 0 { return nil }

        // Defensive: if writer lies, clamp safely.
        // Our C side is documented as "excluding null", so max valid is cap-1.
        if n >= UInt32(cap) { return nil }

        // slice exactly n bytes (excluding null terminator)
        let slice = buf.prefix(Int(n))

        // Validate UTF-8 safely
        return String(validating: slice, as: UTF8.self)
    }

    // ------------------------------------------------------------
    // MARK: - Basic queries
    // ------------------------------------------------------------

    public static func getStatus() -> status {
        status(rawValue: arduino_wifi_status())
    }

    public static func ssid() -> String? {
        readCString { out, outLen in
            arduino_wifi_ssid(out, outLen)
        }
    }

    public static func rssi() -> Int32 {
        arduino_wifi_rssi()
    }

    public static func localIp() -> String? {
        readCString(cap: 32) { out, outLen in
            arduino_wifi_local_ip(out, outLen)
        }
    }

    public static func apIp() -> String? {
        readCString(cap: 32) { out, outLen in
            arduino_wifi_ap_ip(out, outLen)
        }
    }

    // Convenience "safe default" variants (no optional at call site)
    public static func ssidOrEmpty() -> String { ssid() ?? "" }
    public static func localIpOrZero() -> String { localIp() ?? "0.0.0.0" }

    // ------------------------------------------------------------
    // MARK: - STA (connect)
    // ------------------------------------------------------------

    @discardableResult
    public static func staBegin(ssid: String, pass: String) -> status {
        // Guard against empty ssid (avoid passing empty pointers to core)
        if ssid.isEmpty { return status(rawValue: -1) }

        let st: Int32 = withCStringBytes(ssid) { ssidPtr in
            withCStringBytes(pass) { passPtr in
                arduino_wifi_sta_begin(ssidPtr, passPtr)
            }
        }
        return status(rawValue: st)
    }

    @discardableResult
    public static func staBeginOpen(ssid: String) -> status {
        if ssid.isEmpty { return status(rawValue: -1) }
        let st: Int32 = withCStringBytes(ssid) { ssidPtr in
            arduino_wifi_sta_begin_open(ssidPtr)
        }
        return status(rawValue: st)
    }

    public static func disconnect() { arduino_wifi_disconnect() }
    public static func end() { arduino_wifi_end() }

    // ------------------------------------------------------------
    // MARK: - AP (access point)
    // ------------------------------------------------------------

    @discardableResult
    public static func apBegin(ssid: String, pass: String? = nil) -> status {
        if ssid.isEmpty { return status(rawValue: -1) }

        let st: Int32 = withCStringBytes(ssid) { ssidPtr in
            if let pass, !pass.isEmpty {
                return withCStringBytes(pass) { passPtr in
                    arduino_wifi_ap_begin(ssidPtr, passPtr)
                }
            } else {
                return arduino_wifi_ap_begin(ssidPtr, nil)
            }
        }
        return status(rawValue: st)
    }

    public static func apEnd() { arduino_wifi_ap_end() }

    // ------------------------------------------------------------
    // MARK: - Scan
    // ------------------------------------------------------------

    public struct scanResult: Sendable {
        public let ssid: String
        public let rssi: Int32
        public let encryption: Int32
    }

    public static func scan() -> [scanResult] {
        let n = Int(arduino_wifi_scan_begin())
        if n <= 0 { return [] }

        var results: [scanResult] = []
        results.reserveCapacity(n)

        for i in 0..<n {
            let idx = Int32(i)

            // Defensive: if SSID decode fails, use empty string (still keep result)
            let name = readCString { out, outLen in
                arduino_wifi_scan_ssid(idx, out, outLen)
            } ?? ""

            let r = arduino_wifi_scan_rssi(idx)
            let e = arduino_wifi_scan_encryption(idx)

            results.append(scanResult(ssid: name, rssi: r, encryption: e))
        }

        arduino_wifi_scan_end()
        return results
    }

    @inline(__always)
    public static func localIpRaw() -> ip4? {
        var out: [U8] = [0, 0, 0, 0] // fixed 4 bytes
        let n: U32 = out.withUnsafeMutableBufferPointer { p in
            arduino_wifi_local_ip_raw(p.baseAddress!)
        }
        if n != 4 { return nil }
        return ip4(a: out[0], b: out[1], c: out[2], d: out[3])
    }

    // Converts raw IP bytes to a Swift String in a controlled way.
    // This avoids C string writers and UTF-8 decoding pitfalls.
    @inline(__always)
    public static func localIpString() -> String {
        let ip = localIpRaw()
        if ip == nil { return "0.0.0.0" }
        let v = ip!
        // Small, deterministic formatting.
        return "\(v.a).\(v.b).\(v.c).\(v.d)"
    }
}