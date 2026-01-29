// SSD1306+ArduinoAPI.swift
// Swift <-> Arduino SSD1306 bridge

@_silgen_name("arduino_ssd1306_begin")
public func arduino_ssd1306_begin(_ addr: UInt8) -> Void

@_silgen_name("arduino_ssd1306_set_font_system5x7")
public func arduino_ssd1306_set_font_system5x7() -> Void

@_silgen_name("arduino_ssd1306_clear")
public func arduino_ssd1306_clear() -> Void

@_silgen_name("arduino_ssd1306_set_cursor")
public func arduino_ssd1306_set_cursor(_ col: UInt8, _ row: UInt8) -> Void

@_silgen_name("arduino_ssd1306_print_cstr")
public func arduino_ssd1306_print_cstr(_ s: UnsafePointer<CChar>) -> Void