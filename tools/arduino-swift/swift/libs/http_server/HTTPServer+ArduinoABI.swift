// HTTPServer+ArduinoABI.swift
// C-ABI for http_server (UNO R4 WiFi)

@_silgen_name("arduino_http_server_begin")
public func arduino_http_server_begin(_ port: UInt16) -> I32

@_silgen_name("arduino_http_server_end")
public func arduino_http_server_end() -> Void

@_silgen_name("arduino_http_server_client_available")
public func arduino_http_server_client_available() -> I32

@_silgen_name("arduino_http_server_client_connected")
public func arduino_http_server_client_connected() -> I32

@_silgen_name("arduino_http_server_client_read")
public func arduino_http_server_client_read(_ out: UnsafeMutablePointer<U8>?, _ cap: U32) -> I32

@_silgen_name("arduino_http_server_client_write")
public func arduino_http_server_client_write(_ data: UnsafePointer<U8>?, _ len: U32) -> I32

@_silgen_name("arduino_http_server_client_stop")
public func arduino_http_server_client_stop() -> Void