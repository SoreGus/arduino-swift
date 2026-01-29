// ============================================================
// ArduinoSwift - Socket Library (TCP)
// File: swift/libs/socket/socket.swift
//
// Thin, Embedded Swift-friendly wrappers over the C ABI in arduino/libs/socket.
// No external Swift modules required.
//
// IMPORTANT: This file assumes U8 is defined in swift/core/Types.swift.
// ============================================================

public final class TCPClient: @unchecked Sendable {
    private var h: UnsafeMutableRawPointer?

    public init() {
        self.h = _socket_client_create()
    }

    internal init(adopt handle: UnsafeMutableRawPointer) {
        self.h = handle
    }

    deinit {
        _socket_client_destroy(h)
        h = nil
    }

    public func connect(host: String, port: UInt16) -> Bool {
        host.withCString { cstr in
            _socket_client_connect(h, cstr, port)
        }
    }

    public func available() -> Int {
        Int(_socket_client_available(h))
    }

    public func read(into ptr: UnsafeMutablePointer<UInt8>, max: Int) -> Int {
        Int(_socket_client_read(h, ptr, Int32(max)))
    }

    public func write(_ ptr: UnsafePointer<UInt8>, count: Int) -> Int {
        Int(_socket_client_write(h, ptr, Int32(count)))
    }

    public func write(_ bytes: [U8]) -> Int {
        bytes.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return 0 }
            return write(base, count: buf.count)
        }
    }

    public func writeString(_ s: String) -> Int {
        if s.isEmpty { return 0 }
        return write(Array(s.utf8))
    }

    public func connected() -> Bool {
        _socket_client_connected(h)
    }

    public func close() {
        _socket_client_stop(h)
    }
}

public final class TCPServer: @unchecked Sendable {
    private var h: UnsafeMutableRawPointer?

    public init(port: UInt16) {
        self.h = _socket_server_create(port)
    }

    deinit {
        _socket_server_destroy(h)
        h = nil
    }

    @discardableResult
    public func begin() -> Bool {
        _socket_server_begin(h)
    }

    public func accept() -> TCPClient? {
        guard let ch = _socket_server_accept(h) else { return nil }
        return TCPClient(adopt: ch)
    }
}