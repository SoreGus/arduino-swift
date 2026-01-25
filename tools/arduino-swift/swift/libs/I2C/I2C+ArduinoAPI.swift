// I2C+ArduinoAPI.swift
// C-ABI bridge declarations for ArduinoSwiftShim.h (I2C/Wire only).
// Put this file under: swift/libs/I2C/
//
// This file is meant to be included only when the "I2C" lib is enabled in config.json.
//
// Example config.json:
// {
//   "board": "Due",
//   "lib": ["I2C"]
// }

// ----------------------
// I2C (Wire) - Master
// ----------------------
@_silgen_name("arduino_i2c_begin")
public func arduino_i2c_begin() -> Void

@_silgen_name("arduino_i2c_setClock")
public func arduino_i2c_setClock(_ hz: U32) -> Void

@_silgen_name("arduino_i2c_beginTransmission")
public func arduino_i2c_beginTransmission(_ address: U8) -> Void

@_silgen_name("arduino_i2c_write_byte")
public func arduino_i2c_write_byte(_ b: U8) -> U32

@_silgen_name("arduino_i2c_write_buf")
public func arduino_i2c_write_buf(_ data: UnsafePointer<U8>?, _ len: U32) -> U32

@_silgen_name("arduino_i2c_endTransmission")
public func arduino_i2c_endTransmission(_ sendStop: U8) -> U8

@_silgen_name("arduino_i2c_requestFrom")
public func arduino_i2c_requestFrom(_ address: U8, _ quantity: U32, _ sendStop: U8) -> U32

@_silgen_name("arduino_i2c_available")
public func arduino_i2c_available() -> I32

@_silgen_name("arduino_i2c_read")
public func arduino_i2c_read() -> I32

// ----------------------
// I2C (Wire) - Slave
// ----------------------
@_silgen_name("arduino_i2c_slave_begin")
public func arduino_i2c_slave_begin(_ address: U8) -> Void

@_silgen_name("arduino_i2c_slave_rx_available")
public func arduino_i2c_slave_rx_available() -> U32

@_silgen_name("arduino_i2c_slave_rx_read")
public func arduino_i2c_slave_rx_read() -> I32

@_silgen_name("arduino_i2c_slave_rx_read_buf")
public func arduino_i2c_slave_rx_read_buf(_ out: UnsafeMutablePointer<U8>?, _ maxLen: U32) -> U32

@_silgen_name("arduino_i2c_slave_rx_clear")
public func arduino_i2c_slave_rx_clear() -> Void

@_silgen_name("arduino_i2c_slave_set_tx")
public func arduino_i2c_slave_set_tx(_ data: UnsafePointer<U8>?, _ len: U32) -> Void

@_silgen_name("arduino_i2c_slave_consume_onReceive")
public func arduino_i2c_slave_consume_onReceive() -> U32

@_silgen_name("arduino_i2c_slave_consume_onRequest")
public func arduino_i2c_slave_consume_onRequest() -> U32