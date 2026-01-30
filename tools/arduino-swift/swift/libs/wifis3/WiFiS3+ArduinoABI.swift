// WiFiS3+ArduinoABI.swift

@_silgen_name("arduino_wifis3_isAvailable")
public func arduino_wifis3_isAvailable() -> U32

@_silgen_name("arduino_wifis3_begin_ssid_pass")
public func arduino_wifis3_begin_ssid_pass(_ ssid: UnsafePointer<CChar>?, _ pass: UnsafePointer<CChar>?) -> I32

@_silgen_name("arduino_wifis3_begin_ssid")
public func arduino_wifis3_begin_ssid(_ ssid: UnsafePointer<CChar>?) -> I32

@_silgen_name("arduino_wifis3_disconnect")
public func arduino_wifis3_disconnect() -> I32

@_silgen_name("arduino_wifis3_status")
public func arduino_wifis3_status() -> I32

@_silgen_name("arduino_wifis3_rssi")
public func arduino_wifis3_rssi() -> I32

@_silgen_name("arduino_wifis3_localIP_u32")
public func arduino_wifis3_localIP_u32() -> U32

@_silgen_name("arduino_wifis3_gatewayIP_u32")
public func arduino_wifis3_gatewayIP_u32() -> U32

@_silgen_name("arduino_wifis3_subnetMask_u32")
public func arduino_wifis3_subnetMask_u32() -> U32

@_silgen_name("arduino_wifis3_macAddress")
public func arduino_wifis3_macAddress(_ out6: UnsafeMutablePointer<U8>?) -> Void

@_silgen_name("arduino_wifis3_firmwareVersion")
public func arduino_wifis3_firmwareVersion(_ out: UnsafeMutablePointer<CChar>?, _ cap: U32) -> U32

@_silgen_name("arduino_wifis3_ssid")
public func arduino_wifis3_ssid(_ out: UnsafeMutablePointer<CChar>?, _ cap: U32) -> U32

// Scan (opcional)
@_silgen_name("arduino_wifis3_scanNetworks")
public func arduino_wifis3_scanNetworks() -> I32

@_silgen_name("arduino_wifis3_scanDelete")
public func arduino_wifis3_scanDelete() -> Void

@_silgen_name("arduino_wifis3_scan_ssid")
public func arduino_wifis3_scan_ssid(_ index: I32, _ out: UnsafeMutablePointer<CChar>?, _ cap: U32) -> U32

@_silgen_name("arduino_wifis3_scan_rssi")
public func arduino_wifis3_scan_rssi(_ index: I32) -> I32

@_silgen_name("arduino_wifis3_scan_encryptionType")
public func arduino_wifis3_scan_encryptionType(_ index: I32) -> I32

// Helper
@_silgen_name("arduino_wifis3_waitLocalIP_u32")
public func arduino_wifis3_waitLocalIP_u32(_ timeoutMs: U32, _ pollMs: U32) -> U32