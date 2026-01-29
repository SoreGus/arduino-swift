// WiFiSTA.swift (safe adjustments)

public final class WiFiSTA: ArduinoTickable {
    public struct Info: Sendable {
        public let ssid: String
        public let ip: String
        public let rssi: Int32
        public let rawStatus: Int32
    }

    private let ssid: String
    private let pass: String

    private var onConnectBlock: ((Info) -> Void)?
    private var onDisconnectBlock: ((Int32) -> Void)?
    private var onReportBlock: ((Info) -> Void)?

    private var lastStatus: wifi.status = wifi.getStatus()
    private var connectedAtMs: U32 = 0
    private var didFireConnect = false

    private var pollEveryMs: U32 = 200
    private var lastPollMs: U32 = 0

    private var reportEveryMs: U32 = 3000
    private var lastReportMs: U32 = 0

    // IMPORTANT: give the core more time after status==connected
    private var connectWarmupMs: U32 = 1500

    public init(ssid: String, pass: String) {
        self.ssid = ssid
        self.pass = pass
        _ = wifi.staBegin(ssid: ssid, pass: pass)
    }

    @discardableResult
    public func onConnect(_ block: @escaping (Info) -> Void) -> Self { onConnectBlock = block; return self }

    @discardableResult
    public func onDisconnect(_ block: @escaping (Int32) -> Void) -> Self { onDisconnectBlock = block; return self }

    @discardableResult
    public func onReport(everyMs: U32 = 3000, _ block: @escaping (Info) -> Void) -> Self {
        reportEveryMs = everyMs
        onReportBlock = block
        return self
    }

    public func addToRuntime() { ArduinoRuntime.add(self) }

    public func tick() {
        let now = arduino_millis()
        if (now &- lastPollMs) < pollEveryMs { return }
        lastPollMs = now

        let st = wifi.getStatus()

        // Edge: disconnected -> connected
        if st.isConnected && !lastStatus.isConnected {
            connectedAtMs = now
            didFireConnect = false
            lastReportMs = 0
        }

        // Edge: connected -> disconnected
        if !st.isConnected && lastStatus.isConnected {
            didFireConnect = false
            onDisconnectBlock?(st.rawValue)
        }

        lastStatus = st

        if !st.isConnected { return }

        // Wait warmup before reading String values (SSID/IP)
        if (now &- connectedAtMs) < connectWarmupMs { return }

        // onConnect (once)
        if !didFireConnect {
            didFireConnect = true
            onConnectBlock?(readInfo(rawStatus: st.rawValue))
        }

        // periodic report
        if let onReportBlock {
            if (now &- lastReportMs) >= reportEveryMs {
                lastReportMs = now
                onReportBlock(readInfo(rawStatus: st.rawValue))
            }
        }
    }

    private func readInfo(rawStatus: Int32) -> Info {
        // Each getter is called once.
        let s = wifi.ssid() ?? ""
        let ip = wifi.localIp() ?? "0.0.0.0"
        let r = wifi.rssi()
        return Info(ssid: s, ip: ip, rssi: r, rawStatus: rawStatus)
    }
}