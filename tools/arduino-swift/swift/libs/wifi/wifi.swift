// ============================================================
// File: swift/libs/wifi/wifi.swift
// ArduinoSwift - WiFi lib (STA + AP)
//
// Tick-driven WiFi STA and WiFi AP helpers.
// - WiFiSTA connects with timeout + reports.
// - WiFiAP starts SoftAP with timeout + reports.
//
// IMPORTANT (embedded Swift):
// - Avoid nested String.withCString in firmware.
// - Keep NUL-terminated C buffers alive as stored properties.
// - This prevents optimizer/lifetime issues that can hardfault.
//
// Uses ArduinoTime.millis() and the C ABI from arduino/libs/wifi.
// ============================================================

fileprivate func _asw_makeCString(_ s: String) -> [CChar] {
    // NUL-terminated UTF-8 (ASCII compatible for SSID/pass)
    var out = s.utf8.map { CChar(bitPattern: $0) }
    out.append(0)
    return out
}

public struct WiFiInfo: Sendable {
    public let ssid: String
    public let ip: String
    public let rssi: I32
}

public final class WiFiSTA: ArduinoTickable {

    public typealias OnConnect = (WiFiInfo) -> Void
    public typealias OnDisconnect = (U32) -> Void
    public typealias OnReport = (WiFiInfo) -> Void

    private enum State {
        case idle
        case connecting(deadline: U32)
        case connected
        case failed(deadline: U32)
    }

    private var state: State = .idle

    private var ssid: String = ""
    private var pass: String = ""

    // Persisted NUL-terminated buffers (stable pointers for C)
    private var ssidC: [CChar] = [0]
    private var passC: [CChar] = [0]

    private var onConnectBlock: OnConnect?
    private var onDisconnectBlock: OnDisconnect?
    private var onReportBlock: OnReport?

    private var reportEveryMs: U32 = 0
    private var nextReportAt: U32 = 0

    public init(ssid: String, pass: String) {
        self.ssid = ssid
        self.pass = pass
        self.ssidC = _asw_makeCString(ssid)
        self.passC = _asw_makeCString(pass)
    }

    @discardableResult
    public func onConnect(_ cb: @escaping OnConnect) -> Self {
        self.onConnectBlock = cb
        return self
    }

    @discardableResult
    public func onDisconnect(_ cb: @escaping OnDisconnect) -> Self {
        self.onDisconnectBlock = cb
        return self
    }

    @discardableResult
    public func onReport(everyMs: U32, _ cb: @escaping OnReport) -> Self {
        self.reportEveryMs = everyMs
        self.onReportBlock = cb
        return self
    }

    public func begin(timeoutMs: U32 = 15_000) {
        print("Checkpoint 7\n")

        // Use stable pointers (no nested withCString)
        ssidC.withUnsafeBufferPointer { ssidBuf in
            passC.withUnsafeBufferPointer { passBuf in
                guard let s = ssidBuf.baseAddress, let p = passBuf.baseAddress else { return }
                let _ = _wifi_sta_begin(s, p) // ignore return by design
            }
        }

        let now = ArduinoTime.millis()
        self.state = .connecting(deadline: now &+ timeoutMs)

        print("Checkpoint 8\n")
    }

    public func disconnect() {
        _wifi_sta_disconnect()
        state = .idle
    }

    public func tick() {
        switch state {

        case .idle:
            if !ssid.isEmpty {
                begin()
            }

        case .connecting(let deadline):
            let st = _wifi_sta_status()
            if st == WiFiStatus.connected {
                state = .connected
                let info = readInfo()
                nextReportAt = ArduinoTime.millis() &+ reportEveryMs
                onConnectBlock?(info)
                return
            }

            let now = ArduinoTime.millis()
            if isPastDeadline(now: now, deadline: deadline) {
                _wifi_sta_disconnect()
                state = .failed(deadline: now &+ 3_000)
                onDisconnectBlock?(U32(st))
            }

        case .connected:
            let st = _wifi_sta_status()
            if st != WiFiStatus.connected {
                state = .idle
                onDisconnectBlock?(U32(st))
                return
            }

            if reportEveryMs > 0 && onReportBlock != nil {
                let now = ArduinoTime.millis()
                if isPastDeadline(now: now, deadline: nextReportAt) {
                    nextReportAt = now &+ reportEveryMs
                    onReportBlock?(readInfo())
                }
            }

        case .failed(let deadline):
            let now = ArduinoTime.millis()
            if isPastDeadline(now: now, deadline: deadline) {
                state = .idle
            }
        }
    }

    private func readInfo() -> WiFiInfo {
        let ss = String(cString: _wifi_sta_ssid())
        var ipBuf: [CChar] = Array(repeating: 0, count: 16)
        _wifi_sta_local_ip(&ipBuf, 16)
        let ip = String(cString: ipBuf)
        let rssi = I32(_wifi_sta_rssi())
        return WiFiInfo(ssid: ss, ip: ip, rssi: rssi)
    }

    @inline(__always)
    private func isPastDeadline(now: U32, deadline: U32) -> Bool {
        return (now &- deadline) < 0x8000_0000
    }
}

public final class WiFiAP: ArduinoTickable {

    public typealias OnStart = (WiFiInfo) -> Void
    public typealias OnStop = (U32) -> Void

    private enum State {
        case idle
        case starting(deadline: U32)
        case started
    }

    private var state: State = .idle

    private var ssid: String = ""
    private var pass: String = ""

    // Persisted NUL-terminated buffers (stable pointers for C)
    private var ssidC: [CChar] = [0]
    private var passC: [CChar] = [0]

    private var onStartBlock: OnStart?
    private var onStopBlock: OnStop?

    public init(ssid: String, pass: String) {
        self.ssid = ssid
        self.pass = pass
        self.ssidC = _asw_makeCString(ssid)
        self.passC = _asw_makeCString(pass)
    }

    @discardableResult
    public func onStart(_ cb: @escaping OnStart) -> Self {
        self.onStartBlock = cb
        return self
    }

    @discardableResult
    public func onStop(_ cb: @escaping OnStop) -> Self {
        self.onStopBlock = cb
        return self
    }

    public func begin(timeoutMs: U32 = 10_000) {
        print("Checkpoint 9\n")

        ssidC.withUnsafeBufferPointer { ssidBuf in
            passC.withUnsafeBufferPointer { passBuf in
                guard let s = ssidBuf.baseAddress, let p = passBuf.baseAddress else { return }
                let _ = _wifi_ap_begin(s, p) // ignore return by design
            }
        }

        let now = ArduinoTime.millis()
        state = .starting(deadline: now &+ timeoutMs)

        print("Checkpoint 10\n")
    }

    public func stop() {
        _wifi_ap_stop()
        state = .idle
    }

    public func tick() {
        switch state {

        case .idle:
            break

        case .starting(let deadline):
            let st = _wifi_ap_status()
            if st == WiFiStatus.connected || st == WiFiStatus.apListening {
                state = .started
                onStartBlock?(readInfo())
                return
            }

            let now = ArduinoTime.millis()
            if isPastDeadline(now: now, deadline: deadline) {
                _wifi_ap_stop()
                state = .idle
                onStopBlock?(U32(st))
            }

        case .started:
            let st = _wifi_ap_status()
            if st != WiFiStatus.connected && st != WiFiStatus.apListening {
                state = .idle
                onStopBlock?(U32(st))
            }
        }
    }

    private func readInfo() -> WiFiInfo {
        let ss = String(cString: _wifi_sta_ssid())
        var ipBuf: [CChar] = Array(repeating: 0, count: 16)
        _wifi_sta_local_ip(&ipBuf, 16)
        let ip = String(cString: ipBuf)
        let rssi = I32(_wifi_sta_rssi())
        return WiFiInfo(ssid: ss, ip: ip, rssi: rssi)
    }

    @inline(__always)
    private func isPastDeadline(now: U32, deadline: U32) -> Bool {
        return (now &- deadline) < 0x8000_0000
    }
}

public enum WiFiStatus {
    public static let idle: I32 = 0
    public static let noSSID: I32 = 1
    public static let scanCompleted: I32 = 2
    public static let connected: I32 = 3
    public static let connectFailed: I32 = 4
    public static let connectionLost: I32 = 5
    public static let disconnected: I32 = 6
    public static let apListening: I32 = 20
}

// C ABI
@_silgen_name("_wifi_sta_begin") private func _wifi_sta_begin(_ ssid: UnsafePointer<CChar>, _ pass: UnsafePointer<CChar>) -> I32
@_silgen_name("_wifi_sta_disconnect") private func _wifi_sta_disconnect()
@_silgen_name("_wifi_sta_status") private func _wifi_sta_status() -> I32
@_silgen_name("_wifi_sta_ssid") private func _wifi_sta_ssid() -> UnsafePointer<CChar>
@_silgen_name("_wifi_sta_local_ip") private func _wifi_sta_local_ip(_ out: UnsafeMutablePointer<CChar>, _ outLen: I32)
@_silgen_name("_wifi_sta_rssi") private func _wifi_sta_rssi() -> I32

@_silgen_name("_wifi_ap_begin") private func _wifi_ap_begin(_ ssid: UnsafePointer<CChar>, _ pass: UnsafePointer<CChar>) -> I32
@_silgen_name("_wifi_ap_stop") private func _wifi_ap_stop()
@_silgen_name("_wifi_ap_status") private func _wifi_ap_status() -> I32