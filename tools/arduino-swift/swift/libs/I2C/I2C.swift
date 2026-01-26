// I2C.swift
// High-level Swift I2C (Wire) wrapper for ArduinoSwiftShim.
//
// Goals
// -----
// - Everything I2C-related lives here (master + slave + packet + polling devices + helpers)
// - No top-level code. Safe with -parse-as-library.
// - Designed to keep App.swift tiny:
//     - create a bus/device
//     - set closures (onReceive/onRequest/onError)
//     - ArduinoRuntime.add(...)
//     - ArduinoRuntime.keepAlive()
//
// Assumptions
// -----------
// - You have ArduinoRuntime.swift providing:
//       public protocol ArduinoTickable: AnyObject { func tick() }
//       public enum ArduinoRuntime { static func add(...); static func keepAlive() -> Never; ... }
// - You have Serial.swift providing Serial.begin(...) and Serial.print(...) overloads
// - ArduinoSwiftShim exposes these C symbols (defined in ArduinoSwiftShim.h/.cpp):
//     Master (Wire):
//       arduino_i2c_begin()
//       arduino_i2c_setClock(hz)
//       arduino_i2c_beginTransmission(addr)
//       arduino_i2c_write_byte(b)
//       arduino_i2c_write_buf(ptr,len)
//       arduino_i2c_endTransmission(stop)
//       arduino_i2c_requestFrom(addr, qty, stop)
//       arduino_i2c_available()
//       arduino_i2c_read()
//     Slave (Wire ISR flags + buffers in shim):
//       arduino_i2c_slave_begin(addr)
//       arduino_i2c_slave_rx_available()
//       arduino_i2c_slave_rx_read_buf(out,maxLen)
//       arduino_i2c_slave_set_tx(ptr,len)
//       arduino_i2c_slave_consume_onReceive()
//       arduino_i2c_slave_consume_onRequest()
//
// Notes (important)
// -----------------
// - I2C is always master-driven. Slaves do NOT push data spontaneously.
//   Therefore, "master onReceive" in this library means:
//     - a callback invoked when *the master requests data* (requestFrom / polling)
// - "Broadcast" does not exist at hardware level. This library implements broadcast by iterating
//   over a list of addresses (software broadcast).
//
// Example (Master + polling)
// --------------------------
// @_silgen_name("arduino_swift_main")
// public func arduino_swift_main() {
//     Serial.begin(115200)
//     Serial.print("Boot\n")
//
//     let bus = I2C.Bus(clockHz: 100_000)
//
//     // Receive data from slaves when we poll/request
//     bus.onReceive { from, packet in
//         Serial.print("RX from 0x")
//         I2C.Print.hex2(from)
//         Serial.print(": ")
//
//         if let s = packet.asUTF8String() {
//             Serial.print(s)
//             Serial.print("\n")
//         } else {
//             I2C.Print.hexBytes(packet.bytes)
//             Serial.print("\n")
//         }
//     }
//
//     // Poll slave 0x12 every 50ms, expecting up to 32 bytes
//     let poller = bus.poller(from: 0x12, count: 32, everyMs: 50)
//     ArduinoRuntime.add(poller)
//
//     // Send different payload types
//     _ = bus.send(to: 0x12, "hello")
//     _ = bus.send(to: 0x12, Int32(10))
//     _ = bus.send(to: 0x12, UInt8(0x01))
//     _ = bus.send(to: 0x12, [0x01, 0x02, 0x03])
//
//     ArduinoRuntime.keepAlive()
// }
//
// Example (Slave)
// ---------------
// @_silgen_name("arduino_swift_main")
// public func arduino_swift_main() {
//     Serial.begin(115200)
//     Serial.print("Slave boot\n")
//
//     let dev = I2C.SlaveDevice(address: 0x12)
//
//     dev.onReceive { packet in
//         Serial.print("Got ")
//         Serial.print(packet.count)
//         Serial.print(" bytes\n")
//     }
//
//     dev.onRequest {
//         // Return bytes that will be sent when master requests data
//         return I2C.Packet(utf8: "pong")
//     }
//
//     ArduinoRuntime.add(dev)
//     ArduinoRuntime.keepAlive()
// }

public enum I2C {

    // ------------------------------------------------------------
    // MARK: - Status (Wire endTransmission codes)
    // ------------------------------------------------------------
    public struct Status: RawRepresentable, Equatable, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public var isOK: Bool { rawValue == 0 }

        public static let ok          = Status(rawValue: 0)
        public static let dataTooLong = Status(rawValue: 1)
        public static let nackAddress = Status(rawValue: 2)
        public static let nackData    = Status(rawValue: 3)
        public static let otherError  = Status(rawValue: 4)

        public var name: StaticString {
            switch rawValue {
            case 0: return "OK"
            case 1: return "DataTooLong"
            case 2: return "NackAddress"
            case 3: return "NackData"
            default: return "OtherError"
            }
        }
    }

    // ------------------------------------------------------------
    // MARK: - Packet (typed views over bytes)
    // ------------------------------------------------------------
    public struct Packet: Sendable {

        public var bytes: [UInt8]

        @inline(__always)
        public init(_ bytes: [UInt8]) {
            self.bytes = bytes
        }

        @inline(__always)
        public init(byte: UInt8) {
            self.bytes = [byte]
        }

        /// Little-endian Int32 payload (4 bytes)
        @inline(__always)
        public init(int32LE v: Int32) {
            let u = UInt32(bitPattern: v)
            self.bytes = [
                UInt8(truncatingIfNeeded: u),
                UInt8(truncatingIfNeeded: u >> 8),
                UInt8(truncatingIfNeeded: u >> 16),
                UInt8(truncatingIfNeeded: u >> 24),
            ]
        }

        /// Little-endian UInt32 payload (4 bytes)
        @inline(__always)
        public init(uint32LE v: UInt32) {
            self.bytes = [
                UInt8(truncatingIfNeeded: v),
                UInt8(truncatingIfNeeded: v >> 8),
                UInt8(truncatingIfNeeded: v >> 16),
                UInt8(truncatingIfNeeded: v >> 24),
            ]
        }

        /// UTF-8 payload (no null terminator, raw bytes)
        public init(utf8 s: String) {
            self.bytes = Array(s.utf8)
        }

        public var count: Int { bytes.count }
        public var isEmpty: Bool { bytes.isEmpty }

        public func byte(at i: Int) -> UInt8? {
            if i < 0 || i >= bytes.count { return nil }
            return bytes[i]
        }

        /// Try decode bytes as UTF-8 String (returns nil if invalid UTF-8)
        public func asUTF8String() -> String? {
            // Embedded Swift uses the "validating:as:" form.
            String(validating: bytes, as: UTF8.self)
        }

        /// Interpret first 4 bytes as LE UInt32
        public func asUInt32LE() -> UInt32? {
            if bytes.count < 4 { return nil }
            let b0 = UInt32(bytes[0])
            let b1 = UInt32(bytes[1]) << 8
            let b2 = UInt32(bytes[2]) << 16
            let b3 = UInt32(bytes[3]) << 24
            return (b0 | b1 | b2 | b3)
        }

        /// Interpret first 4 bytes as LE Int32
        public func asInt32LE() -> Int32? {
            guard let u = asUInt32LE() else { return nil }
            return Int32(bitPattern: u)
        }
    }

    // ------------------------------------------------------------
    // MARK: - Master (low-level)
    // ------------------------------------------------------------
    public struct Master: Sendable {

        public var clockHz: UInt32
        public let defaultStop: Bool

        // One Wire instance on Arduino: keep single begin flag.
        // Must not be private if used by inline methods.
        static var didBegin: Bool = false

        public init(clockHz: UInt32 = 100_000, defaultStop: Bool = true) {
            self.clockHz = clockHz
            self.defaultStop = defaultStop
        }

        @inline(__always)
        public mutating func beginIfNeeded() {
            if !Self.didBegin {
                arduino_i2c_begin()
                Self.didBegin = true
            }
            arduino_i2c_setClock(clockHz)
        }

        @inline(__always)
        public mutating func setClock(_ hz: UInt32) {
            clockHz = hz
            beginIfNeeded()
        }

        // ----------------------
        // Master write (Wire)
        // ----------------------

        /// beginTransmission(addr) + write(bytes) + endTransmission(stop)
        @inline(__always)
        public mutating func write(to address: UInt8, bytes: [UInt8], sendStop: Bool? = nil) -> Status {
            beginIfNeeded()

            arduino_i2c_beginTransmission(address)
            if !bytes.isEmpty {
                bytes.withUnsafeBufferPointer { buf in
                    _ = arduino_i2c_write_buf(buf.baseAddress, UInt32(buf.count))
                }
            }

            let stop = (sendStop ?? defaultStop) ? UInt8(1) : UInt8(0)
            return Status(rawValue: arduino_i2c_endTransmission(stop))
        }

        /// write one byte
        @inline(__always)
        public mutating func write(to address: UInt8, byte: UInt8, sendStop: Bool? = nil) -> Status {
            beginIfNeeded()

            arduino_i2c_beginTransmission(address)
            _ = arduino_i2c_write_byte(byte)

            let stop = (sendStop ?? defaultStop) ? UInt8(1) : UInt8(0)
            return Status(rawValue: arduino_i2c_endTransmission(stop))
        }

        /// write Packet
        @inline(__always)
        public mutating func write(to address: UInt8, packet: Packet, sendStop: Bool? = nil) -> Status {
            write(to: address, bytes: packet.bytes, sendStop: sendStop)
        }

        // ----------------------
        // Master read (Wire)
        // ----------------------

        /// requestFrom(addr,count,stop) then read available bytes (up to count).
        /// Returns a Packet containing 0...count bytes depending on device response.
        public mutating func read(from address: UInt8, count: Int, sendStop: Bool? = nil) -> Packet {
            if count <= 0 { return Packet([]) }
            beginIfNeeded()

            let stop = (sendStop ?? defaultStop) ? UInt8(1) : UInt8(0)
            let got = Int(arduino_i2c_requestFrom(address, UInt32(count), stop))

            var out: [UInt8] = []
            out.reserveCapacity(got > 0 ? got : count)
            let target = (got > 0 && got <= count) ? got : count

            while out.count < target {
                let avail = Int(arduino_i2c_available())
                if avail <= 0 { break }

                let v = arduino_i2c_read()
                if v < 0 { break }
                out.append(UInt8(truncatingIfNeeded: v))
            }

            return Packet(out)
        }

        // ----------------------
        // Master utilities
        // ----------------------

        /// Classic I2C bus scan: tries each addr with beginTransmission/endTransmission.
        public mutating func scan(range: ClosedRange<UInt8> = 0x08...0x77) -> [UInt8] {
            beginIfNeeded()
            var found: [UInt8] = []
            for addr in range {
                arduino_i2c_beginTransmission(addr)
                let st = arduino_i2c_endTransmission(1)
                if st == 0 { found.append(addr) }
            }
            return found
        }

        /// Combined "write then read" pattern:
        /// - Useful for register-based devices: write register address, then read N bytes.
        public mutating func writeRead(
            to address: UInt8,
            write: [UInt8],
            readCount: Int,
            sendStopAfterWrite: Bool = false,
            sendStopAfterRead: Bool = true
        ) -> (status: Status, packet: Packet) {
            // Many devices require a repeated-start: endTransmission(false) then requestFrom(..., true)
            let st = self.write(to: address, bytes: write, sendStop: sendStopAfterWrite)
            if !st.isOK {
                return (st, Packet([]))
            }
            let pkt = self.read(from: address, count: readCount, sendStop: sendStopAfterRead)
            return (st, pkt)
        }
    }

    // ------------------------------------------------------------
    // MARK: - Bus (high-level Master API with completions)
    // ------------------------------------------------------------
    /// High-level master bus:
    /// - exposes send(...) overloads
    /// - exposes request(...) overloads
    /// - provides onReceive/onError callbacks triggered by request/pollers
    ///
    /// Note: Master is still synchronous (I2C is fast), but "completion" here means
    ///       closure-based API to keep App.swift clean and uniform.
    public final class Bus {

        // Underlying low-level master
        private var master: Master

        // Internal storage for handlers
        private var onReceiveHandler: ((UInt8, Packet) -> Void)?
        private var onErrorHandler: ((UInt8, Status) -> Void)?

        // --------------------------------------------------
        // MARK: - Handlers (property-style + fluent-style)
        // --------------------------------------------------
        // Property-style:
        //   bus.onReceive = { from, packet in ... }
        //   bus.onError   = { addr, status in ... }
        // Fluent-style:
        //   bus.onReceive { from, packet in ... }
        //   bus.onError { addr, status in ... }

        public var onReceive: ((UInt8, Packet) -> Void)? {
            get { onReceiveHandler }
            set { onReceiveHandler = newValue }
        }

        public var onError: ((UInt8, Status) -> Void)? {
            get { onErrorHandler }
            set { onErrorHandler = newValue }
        }

        @inline(__always)
        @discardableResult
        public func onReceive(_ handler: @escaping (UInt8, Packet) -> Void) -> Self {
            self.onReceiveHandler = handler
            return self
        }

        @inline(__always)
        @discardableResult
        public func onError(_ handler: @escaping (UInt8, Status) -> Void) -> Self {
            self.onErrorHandler = handler
            return self
        }


        @inline(__always)
        fileprivate func emitReceive(_ from: UInt8, _ packet: Packet) {
            onReceiveHandler?(from, packet)
        }

        @inline(__always)
        fileprivate func emitError(_ addr: UInt8, _ status: Status) {
            onErrorHandler?(addr, status)
        }

        public init(clockHz: UInt32 = 100_000, defaultStop: Bool = true) {
            self.master = Master(clockHz: clockHz, defaultStop: defaultStop)
            self.master.setClock(clockHz)
        }

        // ----------------------
        // Bus config
        // ----------------------

        public func setClock(_ hz: UInt32) {
            master.setClock(hz)
        }

        public func scan(range: ClosedRange<UInt8> = 0x08...0x77) -> [UInt8] {
            master.scan(range: range)
        }

        // ----------------------
        // SEND overloads (Master -> Slave)
        // ----------------------

        @discardableResult
        public func send(to address: UInt8, _ bytes: [UInt8], stop: Bool? = nil) -> Status {
            let st = master.write(to: address, bytes: bytes, sendStop: stop)
            if !st.isOK { emitError(address, st) }
            return st
        }

        @discardableResult
        public func send(to address: UInt8, _ byte: UInt8, stop: Bool? = nil) -> Status {
            let st = master.write(to: address, byte: byte, sendStop: stop)
            if !st.isOK { emitError(address, st) }
            return st
        }

        @discardableResult
        public func send(to address: UInt8, _ v: Int32, stop: Bool? = nil) -> Status {
            send(to: address, Packet(int32LE: v).bytes, stop: stop)
        }

        /// Convenience for integer literals (e.g. `bus.send(to: 0x12, 10)`)
        @discardableResult
        public func send(to address: UInt8, _ v: Int, stop: Bool? = nil) -> Status {
            let vv: Int32
            if v > Int(Int32.max) { vv = Int32.max }
            else if v < Int(Int32.min) { vv = Int32.min }
            else { vv = Int32(v) }
            return send(to: address, vv, stop: stop)
        }

        @discardableResult
        public func send(to address: UInt8, _ v: UInt32, stop: Bool? = nil) -> Status {
            send(to: address, Packet(uint32LE: v).bytes, stop: stop)
        }

        @discardableResult
        public func send(to address: UInt8, _ text: String, stop: Bool? = nil) -> Status {
            send(to: address, Packet(utf8: text).bytes, stop: stop)
        }

        @discardableResult
        public func send(to address: UInt8, _ packet: Packet, stop: Bool? = nil) -> Status {
            send(to: address, packet.bytes, stop: stop)
        }

        /// Software broadcast: iterate a list of slave addresses.
        public func broadcast(to addresses: [UInt8], _ bytes: [UInt8], stop: Bool? = nil) {
            for a in addresses { _ = send(to: a, bytes, stop: stop) }
        }

        public func broadcast(to addresses: [UInt8], _ text: String, stop: Bool? = nil) {
            for a in addresses { _ = send(to: a, text, stop: stop) }
        }

        // ----------------------
        // REQUEST overloads (Master reads from Slave)
        // ----------------------

        /// Request N bytes from a slave and return Packet.
        @discardableResult
        public func request(from address: UInt8, count: Int, stop: Bool? = nil) -> Packet {
            let pkt = master.read(from: address, count: count, sendStop: stop)
            emitReceive(address, pkt)
            return pkt
        }

        /// Request with completion (closure).
        public func request(from address: UInt8, count: Int, stop: Bool? = nil, completion: (Packet) -> Void) {
            let pkt = request(from: address, count: count, stop: stop)
            completion(pkt)
        }

        /// Write+Read convenience (register-based devices).
        public func writeRead(
            to address: UInt8,
            write: [UInt8],
            readCount: Int,
            repeatedStart: Bool = true,
            completion: ((Status, Packet) -> Void)? = nil
        ) -> (Status, Packet) {
            let sendStopAfterWrite = repeatedStart ? false : true
            let result = master.writeRead(
                to: address,
                write: write,
                readCount: readCount,
                sendStopAfterWrite: sendStopAfterWrite,
                sendStopAfterRead: true
            )

            if !result.status.isOK { emitError(address, result.status) }
            emitReceive(address, result.packet)
            completion?(result.status, result.packet)
            return result
        }

        // ----------------------
        // Runtime-friendly devices
        // ----------------------

        /// Create a Poller device that periodically requests bytes from a slave and fires onReceive.
        public func poller(from address: UInt8, count: Int, everyMs: UInt32) -> Poller {
            Poller(bus: self, address: address, count: count, everyMs: everyMs)
        }

        /// Create a MasterTxRxDevice device:
        /// - periodically sends payload to a slave
        /// - optionally requests a response afterwards
        public func txRxDevice(
            to address: UInt8,
            payload: Packet,
            everyMs: UInt32,
            readCount: Int = 0
        ) -> MasterTxRxDevice {
            MasterTxRxDevice(bus: self, address: address, payload: payload, everyMs: everyMs, readCount: readCount)
        }

        // Internal access for devices
        fileprivate func _sendRaw(to address: UInt8, bytes: [UInt8], stop: Bool?) -> Status {
            master.write(to: address, bytes: bytes, sendStop: stop)
        }

        fileprivate func _requestRaw(from address: UInt8, count: Int, stop: Bool?) -> Packet {
            master.read(from: address, count: count, sendStop: stop)
        }
    }

    // ------------------------------------------------------------
    // MARK: - Poller (ArduinoTickable)
    // ------------------------------------------------------------
    /// Periodically requests N bytes from a single slave address.
    /// This is the clean way to emulate "master onReceive" behavior.
    public final class Poller: ArduinoTickable {

        private let bus: Bus
        public let address: UInt8
        public var count: Int
        public var everyMs: UInt32

        public var enabled: Bool = true
        public var stop: Bool? = true

        private var lastMs: UInt32 = 0

        public init(bus: Bus, address: UInt8, count: Int, everyMs: UInt32) {
            self.bus = bus
            self.address = address
            self.count = count
            self.everyMs = everyMs
        }

        public func tick() {
            guard enabled else { return }
            let now = arduino_millis()
            if (now &- lastMs) < everyMs { return }
            lastMs = now

            let pkt = bus._requestRaw(from: address, count: count, stop: stop)
            bus.emitReceive(address, pkt)
        }
    }

    // ------------------------------------------------------------
    // MARK: - MasterTxRxDevice (ArduinoTickable)
    // ------------------------------------------------------------
    /// Periodically sends a payload to slave and optionally requests a response.
    /// Great for demos and quick device bring-up without cluttering App.swift.
    public final class MasterTxRxDevice: ArduinoTickable {

        public enum Mode {
            case writeOnly
            case writeThenRead
        }

        private let bus: Bus
        public let address: UInt8
        public var payload: Packet
        public var readCount: Int
        public var everyMs: UInt32

        public var enabled: Bool = true
        public var stopAfterWrite: Bool? = true
        public var stopAfterRead: Bool? = true

        public var onTickResult: ((Status, Packet) -> Void)?

        private var lastMs: UInt32 = 0

        public init(bus: Bus, address: UInt8, payload: Packet, everyMs: UInt32, readCount: Int) {
            self.bus = bus
            self.address = address
            self.payload = payload
            self.everyMs = everyMs
            self.readCount = readCount
        }

        public var mode: Mode {
            readCount > 0 ? .writeThenRead : .writeOnly
        }

        public func tick() {
            guard enabled else { return }
            let now = arduino_millis()
            if (now &- lastMs) < everyMs { return }
            lastMs = now

            // Write
            let st = bus._sendRaw(to: address, bytes: payload.bytes, stop: stopAfterWrite)
            if !st.isOK { bus.emitError(address, st) }

            var pkt = Packet([])
            if readCount > 0, st.isOK {
                pkt = bus._requestRaw(from: address, count: readCount, stop: stopAfterRead)
                bus.emitReceive(address, pkt)
            }

            onTickResult?(st, pkt)
        }
    }

    // ------------------------------------------------------------
    // MARK: - Slave (low-level, driven by shim flags)
    // ------------------------------------------------------------
    public final class Slave: ArduinoTickable {

        public let address: UInt8

        private var didBegin: Bool = false

        // Scratch buffer for draining RX ring from shim
        private var rxScratch: [UInt8] = Array(repeating: 0, count: 64)

        // TX payload storage must stay alive until shim snapshots it in ISR
        private var txPayload: [UInt8] = []

        /// Called when master writes to this slave.
        public var onReceive: ((Packet) -> Void)?

        /// Called when master requests data. Return payload to send.
        /// If nil => send empty payload.
        public var onRequest: (() -> Packet)?

        public init(address: UInt8) {
            self.address = address
        }

        public func begin() {
            if didBegin { return }
            arduino_i2c_slave_begin(address)
            didBegin = true
        }

        public func tick() {
            if !didBegin { begin() }

            // On receive
            if arduino_i2c_slave_consume_onReceive() != 0 {
                drainReceiveAndCallback()
            }

            // On request
            if arduino_i2c_slave_consume_onRequest() != 0 {
                prepareTxFromCallback()
            }
        }

        private func drainReceiveAndCallback() {
            let avail = Int(arduino_i2c_slave_rx_available())
            if avail <= 0 {
                onReceive?(Packet([]))
                return
            }

            var all: [UInt8] = []
            all.reserveCapacity(avail)

            while true {
                let a = Int(arduino_i2c_slave_rx_available())
                if a <= 0 { break }

                let chunk = min(a, rxScratch.count)
                let got: UInt32 = rxScratch.withUnsafeMutableBufferPointer { buf in
                    arduino_i2c_slave_rx_read_buf(buf.baseAddress, UInt32(chunk))
                }
                if got == 0 { break }

                all.append(contentsOf: rxScratch[0..<Int(got)])
            }

            onReceive?(Packet(all))
        }

        private func prepareTxFromCallback() {
            guard let mk = onRequest else {
                arduino_i2c_slave_set_tx(nil, 0)
                return
            }

            let packet = mk()
            txPayload = packet.bytes

            if txPayload.isEmpty {
                arduino_i2c_slave_set_tx(nil, 0)
                return
            }

            txPayload.withUnsafeBufferPointer { buf in
                arduino_i2c_slave_set_tx(buf.baseAddress, UInt32(buf.count))
            }
        }
    }

    // ------------------------------------------------------------
    // MARK: - SlaveDevice (nice ergonomic wrapper)
    // ------------------------------------------------------------
    /// Convenience wrapper over Slave that adds:
    /// - typed send helpers for onRequest
    /// - typed decoding helpers for onReceive
    ///
    /// Usage:
    ///   let dev = I2C.SlaveDevice(address: 0x12)
    ///   dev.onReceive { pkt in ... }
    ///   dev.onRequest { I2C.Packet(utf8: "pong") }
    ///   ArduinoRuntime.add(dev)
    public final class SlaveDevice: ArduinoTickable {

        private let slave: Slave

        public var address: UInt8 { slave.address }

        public var onReceive: ((Packet) -> Void)? {
            get { slave.onReceive }
            set { slave.onReceive = newValue }
        }

        public var onRequest: (() -> Packet)? {
            get { slave.onRequest }
            set { slave.onRequest = newValue }
        }

        public init(address: UInt8) {
            self.slave = Slave(address: address)
        }

        public func begin() { slave.begin() }
        public func tick() { slave.tick() }

        // Typed helpers for responding to master requests
        public func respondBytes(_ bytes: [UInt8]) {
            slave.onRequest = { Packet(bytes) }
        }

        public func respondByte(_ b: UInt8) {
            slave.onRequest = { Packet(byte: b) }
        }

        public func respondInt32LE(_ v: Int32) {
            slave.onRequest = { Packet(int32LE: v) }
        }

        public func respondUInt32LE(_ v: UInt32) {
            slave.onRequest = { Packet(uint32LE: v) }
        }

        public func respondUTF8(_ s: String) {
            slave.onRequest = { Packet(utf8: s) }
        }
    }
}