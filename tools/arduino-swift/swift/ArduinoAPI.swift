// ArduinoAPI.swift
// C-ABI bridge declarations for ArduinoSwiftShim.h
// (Only declarations; logic stays in Swift files or in ArduinoSwiftShim.cpp)

public typealias U32 = UInt32
public typealias I32 = Int32
public typealias U8  = UInt8

// ----------------------
// Digital
// ----------------------
@_silgen_name("arduino_pinMode")
public func arduino_pinMode(_ pin: U32, _ mode: U32) -> Void

@_silgen_name("arduino_digitalWrite")
public func arduino_digitalWrite(_ pin: U32, _ value: U32) -> Void

@_silgen_name("arduino_digitalRead")
public func arduino_digitalRead(_ pin: U32) -> U32

// ----------------------
// Timing
// ----------------------
@_silgen_name("arduino_delay_ms")
public func arduino_delay_ms(_ ms: U32) -> Void

@_silgen_name("arduino_millis")
public func arduino_millis() -> U32

// ----------------------
// Analog
// ----------------------
@_silgen_name("arduino_analogRead")
public func arduino_analogRead(_ pin: U32) -> U32

@_silgen_name("arduino_analogReadResolution")
public func arduino_analogReadResolution(_ bits: U32) -> Void

@_silgen_name("arduino_analogMaxValue")
public func arduino_analogMaxValue() -> U32

// ----------------------
// Constants
// ----------------------
@_silgen_name("arduino_builtin_led")
public func arduino_builtin_led() -> U32

@_silgen_name("arduino_mode_output")
public func arduino_mode_output() -> U32

@_silgen_name("arduino_mode_input")
public func arduino_mode_input() -> U32

@_silgen_name("arduino_mode_input_pullup")
public func arduino_mode_input_pullup() -> U32

@_silgen_name("arduino_high")
public func arduino_high() -> U32

@_silgen_name("arduino_low")
public func arduino_low() -> U32

// ----------------------
// External Interrupts (flag-based)
// ----------------------
@_silgen_name("arduino_irq_mode_low")
public func arduino_irq_mode_low() -> U32

@_silgen_name("arduino_irq_mode_change")
public func arduino_irq_mode_change() -> U32

@_silgen_name("arduino_irq_mode_rising")
public func arduino_irq_mode_rising() -> U32

@_silgen_name("arduino_irq_mode_falling")
public func arduino_irq_mode_falling() -> U32

@_silgen_name("arduino_irq_mode_high")
public func arduino_irq_mode_high() -> U32

@_silgen_name("arduino_irq_attach")
public func arduino_irq_attach(_ pin: U32, _ mode: U32) -> I32

@_silgen_name("arduino_irq_detach")
public func arduino_irq_detach(_ slot: I32) -> Void

@_silgen_name("arduino_irq_consume")
public func arduino_irq_consume(_ slot: I32) -> U32

@_silgen_name("arduino_digitalPinToInterrupt")
public func arduino_digitalPinToInterrupt(_ pin: U32) -> I32

// ----------------------
// Serial
// ----------------------
@_silgen_name("arduino_serial_begin")
public func arduino_serial_begin(_ baud: U32) -> Void

@_silgen_name("arduino_serial_print_cstr")
public func arduino_serial_print_cstr(_ s: UnsafePointer<CChar>) -> Void

@_silgen_name("arduino_serial_print_i32")
public func arduino_serial_print_i32(_ v: I32) -> Void

@_silgen_name("arduino_serial_print_u32")
public func arduino_serial_print_u32(_ v: U32) -> Void

@_silgen_name("arduino_serial_print_f64")
public func arduino_serial_print_f64(_ v: Double) -> Void

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
// ^ Agora `nil` funciona e NÃO dá "nil requires a contextual type"

@_silgen_name("arduino_i2c_slave_consume_onReceive")
public func arduino_i2c_slave_consume_onReceive() -> U32

@_silgen_name("arduino_i2c_slave_consume_onRequest")
public func arduino_i2c_slave_consume_onRequest() -> U32

// ----------------------
// SPI (for later)
// ----------------------
@_silgen_name("arduino_spi_begin")
public func arduino_spi_begin() -> Void

@_silgen_name("arduino_spi_end")
public func arduino_spi_end() -> Void

@_silgen_name("arduino_spi_beginTransaction")
public func arduino_spi_beginTransaction(_ clockHz: U32, _ bitOrder: U8, _ dataMode: U8) -> Void

@_silgen_name("arduino_spi_endTransaction")
public func arduino_spi_endTransaction() -> Void

@_silgen_name("arduino_spi_transfer")
public func arduino_spi_transfer(_ v: U8) -> U8

@_silgen_name("arduino_spi_transfer_buf")
public func arduino_spi_transfer_buf(_ data: UnsafeMutablePointer<U8>?, _ len: U32) -> U32