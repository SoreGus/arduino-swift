// ArduinoAPI.swift
// Minimal C-ABI bridge into Arduino core functions
// Implemented by ArduinoSwiftShim.cpp
//
// RULES:
// - No logic here. Only @_silgen_name declarations.
// - Higher-level stuff lives in PIN / AnalogPIN / Button / Serial.

public typealias U32 = UInt32
public typealias I32 = Int32
public typealias F64 = Double

// --------------------------------------------------
// MARK: - Digital I/O
// --------------------------------------------------

@_silgen_name("arduino_pinMode")
public func arduino_pinMode(_ pin: U32, _ mode: U32)

@_silgen_name("arduino_digitalWrite")
public func arduino_digitalWrite(_ pin: U32, _ value: U32)

@_silgen_name("arduino_digitalRead")
public func arduino_digitalRead(_ pin: U32) -> U32

// --------------------------------------------------
// MARK: - Timing
// --------------------------------------------------

@_silgen_name("arduino_delay_ms")
public func arduino_delay_ms(_ ms: U32)

@_silgen_name("arduino_millis")
public func arduino_millis() -> U32

// --------------------------------------------------
// MARK: - Analog
// --------------------------------------------------

@_silgen_name("arduino_analogRead")
public func arduino_analogRead(_ pin: U32) -> U32

@_silgen_name("arduino_analogReadResolution")
public func arduino_analogReadResolution(_ bits: U32)

@_silgen_name("arduino_analogMaxValue")
public func arduino_analogMaxValue() -> U32

// --------------------------------------------------
// MARK: - Constants / Helpers
// --------------------------------------------------

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

// --------------------------------------------------
// MARK: - External Interrupts (flag-based)
// --------------------------------------------------

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
public func arduino_irq_detach(_ slot: I32)

@_silgen_name("arduino_irq_consume")
public func arduino_irq_consume(_ slot: I32) -> U32

@_silgen_name("arduino_digitalPinToInterrupt")
public func arduino_digitalPinToInterrupt(_ pin: U32) -> I32

// --------------------------------------------------
// MARK: - Serial
// --------------------------------------------------

@_silgen_name("arduino_serial_begin")
public func arduino_serial_begin(_ baud: U32)

@_silgen_name("arduino_serial_print_cstr")
public func arduino_serial_print_cstr(_ cstr: UnsafePointer<CChar>)

@_silgen_name("arduino_serial_print_i32")
public func arduino_serial_print_i32(_ v: I32)

@_silgen_name("arduino_serial_print_u32")
public func arduino_serial_print_u32(_ v: U32)

@_silgen_name("arduino_serial_print_f64")
public func arduino_serial_print_f64(_ v: F64)