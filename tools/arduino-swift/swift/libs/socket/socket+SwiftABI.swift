// ============================================================
// ArduinoSwift - Socket Library Swift ABI
// File: swift/libs/socket/socketSwiftABI.swift
//
// Declares C ABI symbols from arduino/libs/socket.
// Required as <lib>SwiftABI.swift entry for 'socket'.
// ============================================================

@_silgen_name("socket_server_create")
internal func _socket_server_create(_ port: UInt16) -> UnsafeMutableRawPointer?

@_silgen_name("socket_server_destroy")
internal func _socket_server_destroy(_ s: UnsafeMutableRawPointer?)

@_silgen_name("socket_server_begin")
internal func _socket_server_begin(_ s: UnsafeMutableRawPointer?) -> Bool

@_silgen_name("socket_server_accept")
internal func _socket_server_accept(_ s: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

@_silgen_name("socket_client_create")
internal func _socket_client_create() -> UnsafeMutableRawPointer?

@_silgen_name("socket_client_destroy")
internal func _socket_client_destroy(_ c: UnsafeMutableRawPointer?)

@_silgen_name("socket_client_connect")
internal func _socket_client_connect(_ c: UnsafeMutableRawPointer?, _ host: UnsafePointer<CChar>, _ port: UInt16) -> Bool

@_silgen_name("socket_client_available")
internal func _socket_client_available(_ c: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("socket_client_read")
internal func _socket_client_read(_ c: UnsafeMutableRawPointer?, _ out: UnsafeMutablePointer<UInt8>, _ max: Int32) -> Int32

@_silgen_name("socket_client_write")
internal func _socket_client_write(_ c: UnsafeMutableRawPointer?, _ buf: UnsafePointer<UInt8>, _ len: Int32) -> Int32

@_silgen_name("socket_client_connected")
internal func _socket_client_connected(_ c: UnsafeMutableRawPointer?) -> Bool

@_silgen_name("socket_client_stop")
internal func _socket_client_stop(_ c: UnsafeMutableRawPointer?)