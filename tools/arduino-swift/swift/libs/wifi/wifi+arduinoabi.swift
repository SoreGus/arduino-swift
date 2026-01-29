// wifi+arduinoabi.swift
// c-abi bridge declarations for arduinoSwift wifi library.
// include this file only when the wifi lib is enabled.

@_silgen_name("arduino_wifi_status")
public func arduino_wifi_status() -> I32

@_silgen_name("arduino_wifi_sta_begin")
public func arduino_wifi_sta_begin(_ ssid: UnsafePointer<U8>?, _ pass: UnsafePointer<U8>?) -> I32

@_silgen_name("arduino_wifi_sta_begin_open")
public func arduino_wifi_sta_begin_open(_ ssid: UnsafePointer<U8>?) -> I32

@_silgen_name("arduino_wifi_disconnect")
public func arduino_wifi_disconnect() -> Void

@_silgen_name("arduino_wifi_end")
public func arduino_wifi_end() -> Void

@_silgen_name("arduino_wifi_ap_begin")
public func arduino_wifi_ap_begin(_ ssid: UnsafePointer<U8>?, _ pass: UnsafePointer<U8>?) -> I32

@_silgen_name("arduino_wifi_ap_end")
public func arduino_wifi_ap_end() -> Void

@_silgen_name("arduino_wifi_ssid")
public func arduino_wifi_ssid(_ out: UnsafeMutablePointer<U8>?, _ outLen: U32) -> U32

@_silgen_name("arduino_wifi_rssi")
public func arduino_wifi_rssi() -> I32

@_silgen_name("arduino_wifi_local_ip")
public func arduino_wifi_local_ip(_ out: UnsafeMutablePointer<U8>?, _ outLen: U32) -> U32

@_silgen_name("arduino_wifi_ap_ip")
public func arduino_wifi_ap_ip(_ out: UnsafeMutablePointer<U8>?, _ outLen: U32) -> U32

@_silgen_name("arduino_wifi_scan_begin")
public func arduino_wifi_scan_begin() -> I32

@_silgen_name("arduino_wifi_scan_ssid")
public func arduino_wifi_scan_ssid(_ index: I32, _ out: UnsafeMutablePointer<U8>?, _ outLen: U32) -> U32

@_silgen_name("arduino_wifi_scan_rssi")
public func arduino_wifi_scan_rssi(_ index: I32) -> I32

@_silgen_name("arduino_wifi_scan_encryption")
public func arduino_wifi_scan_encryption(_ index: I32) -> I32

@_silgen_name("arduino_wifi_scan_end")
public func arduino_wifi_scan_end() -> Void

@_silgen_name("arduino_wifi_local_ip_raw")
public func arduino_wifi_local_ip_raw(_ out4: UnsafeMutablePointer<U8>?) -> U32