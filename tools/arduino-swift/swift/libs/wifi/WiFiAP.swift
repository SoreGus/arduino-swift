// WiFiAP.swift
// ArduinoSwift - WiFi AP helper (tickable, Button-like)
//
// Goals:
// - Button-like API: onStart / onStop / onStatusChange / onReport
// - Start AP via wifi.apBegin(ssid:pass:) (or open AP if pass nil/empty)
// - Polling status, integrates with ArduinoRuntime
//
// Notes:
// - Some cores don't provide AP IP. If wifi.apIp() returns nil/empty, we print "-".

public final class WiFiAP: ArduinoTickable {

    // MARK: - Types

    public struct Info: Sendable {
        public let ssid: String
        public let ip: String
        public let rssi: Int32
        public let rawStatus: Int32
    }

    public struct StopReason: RawRepresentable, Sendable, Equatable {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
    }

    // MARK: - Config

    private let ssid: String
    private let pass: String?

    // MARK: - Callbacks

    private var onStartBlock: ((Info) -> Void)?
    private var onStopBlock: ((StopReason) -> Void)?
    private var onStatusChangeBlock: ((wifi.status) -> Void)?
    private var onReportBlock: ((Info) -> Void)?

    // MARK: - State

    private var enabled: Bool = true

    private var lastStatus: wifi.status = wifi.getStatus()

    private var didFireStartForThisSession: Bool = false
    private var startedAtMs: U32 = 0

    private var startWarmupMs: U32 = 350
    private var pollEveryMs: U32 = 150

    private var lastPollMs: U32 = 0

    private var reportEveryMs: U32 = 3000
    private var lastReportMs: U32 = 0

    // MARK: - Init

    public init(ssid: String, pass: String? = nil) {
        self.ssid = ssid
        self.pass = pass

        // Start AP immediately.
        _ = wifi.apBegin(ssid: ssid, pass: pass)

        self.lastStatus = wifi.getStatus()
        if self.lastStatus.isConnected {
            self.startedAtMs = arduino_millis()
        }
    }

    // MARK: - Fluent API

    @discardableResult
    public func onStart(_ block: @escaping (Info) -> Void) -> Self {
        self.onStartBlock = block
        return self
    }

    @discardableResult
    public func onStop(_ block: @escaping (StopReason) -> Void) -> Self {
        self.onStopBlock = block
        return self
    }

    @discardableResult
    public func onStatusChange(_ block: @escaping (wifi.status) -> Void) -> Self {
        self.onStatusChangeBlock = block
        return self
    }

    @discardableResult
    public func onReport(everyMs: U32 = 3000, _ block: @escaping (Info) -> Void) -> Self {
        self.reportEveryMs = everyMs
        self.onReportBlock = block
        return self
    }

    // MARK: - Runtime helpers

    public func addToRuntime() {
        ArduinoRuntime.add(self)
    }

    // MARK: - Controls

    public func enable() {
        enabled = true
        lastStatus = wifi.getStatus()
        didFireStartForThisSession = false
        if lastStatus.isConnected {
            startedAtMs = arduino_millis()
        }
    }

    public func disable() { enabled = false }
    public func isEnabled() -> Bool { enabled }

    public func setPollEvery(ms: U32) { pollEveryMs = ms }
    public func setStartWarmup(ms: U32) { startWarmupMs = ms }

    /// Stop AP (and/or WiFi stack depending on core).
    public func stop() {
        wifi.apEnd()
        didFireStartForThisSession = false
    }

    // MARK: - Tick

    public func tick() {
        if enabled == false {
            // No work while disabled.
        } else {
            let now = arduino_millis()
            let dtPoll = now &- lastPollMs

            if dtPoll >= pollEveryMs {
                lastPollMs = now

                let st = wifi.getStatus()

                if st.rawValue != lastStatus.rawValue {
                    onStatusChangeBlock?(st)
                }

                // "Connected" for AP is not always a perfect signal across cores.
                // We still use it as a generic indicator (raw wl_status_t-like).
                if st.isConnected && (lastStatus.isConnected == false) {
                    startedAtMs = now
                    didFireStartForThisSession = false
                    lastReportMs = 0
                }

                if (st.isConnected == false) && lastStatus.isConnected {
                    didFireStartForThisSession = false
                    onStopBlock?(StopReason(rawValue: st.rawValue))
                }

                lastStatus = st

                if st.isConnected {
                    let warm = now &- startedAtMs
                    if warm >= startWarmupMs {
                        if didFireStartForThisSession == false {
                            didFireStartForThisSession = true
                            onStartBlock?(readInfoSafely(rawStatus: st.rawValue))
                        }
                    }
                }

                if st.isConnected && onReportBlock != nil {
                    let warm = now &- startedAtMs
                    if warm >= startWarmupMs {
                        let dtRep = now &- lastReportMs
                        if dtRep >= reportEveryMs {
                            lastReportMs = now
                            onReportBlock?(readInfoSafely(rawStatus: st.rawValue))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Info reading

    private func readInfoSafely(rawStatus: Int32) -> Info {
        let ss: String = wifi.ssid() ?? ""
        let ip: String = wifi.apIp() ?? "-"
        let r: Int32 = wifi.rssi()
        return Info(ssid: ss, ip: ip, rssi: r, rawStatus: rawStatus)
    }
}