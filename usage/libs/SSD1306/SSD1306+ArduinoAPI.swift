// SSD1306+ArduinoAPI.swift
// Swift <-> Arduino bridge (graphics backend)

@_silgen_name("arduino_ssd1306_begin_auto")
public func arduino_ssd1306_begin_auto() -> UInt8

@_silgen_name("arduino_ssd1306_begin_addr")
public func arduino_ssd1306_begin_addr(_ addr: UInt8) -> UInt8

@_silgen_name("arduino_ssd1306_clear")
public func arduino_ssd1306_clear() -> Void

@_silgen_name("arduino_ssd1306_display")
public func arduino_ssd1306_display() -> Void

@_silgen_name("arduino_ssd1306_set_text_size")
public func arduino_ssd1306_set_text_size(_ size: UInt8) -> Void

@_silgen_name("arduino_ssd1306_set_cursor_px")
public func arduino_ssd1306_set_cursor_px(_ x: Int16, _ y: Int16) -> Void

@_silgen_name("arduino_ssd1306_print_cstr")
public func arduino_ssd1306_print_cstr(_ s: UnsafePointer<CChar>) -> Void

@_silgen_name("arduino_ssd1306_set_text_color")
public func arduino_ssd1306_set_text_color(_ color: UInt8) -> Void

@_silgen_name("arduino_ssd1306_draw_pixel")
public func arduino_ssd1306_draw_pixel(_ x: Int16, _ y: Int16, _ color: UInt8) -> Void

@_silgen_name("arduino_ssd1306_draw_line")
public func arduino_ssd1306_draw_line(_ x0: Int16, _ y0: Int16, _ x1: Int16, _ y1: Int16, _ color: UInt8) -> Void

@_silgen_name("arduino_ssd1306_draw_rect")
public func arduino_ssd1306_draw_rect(_ x: Int16, _ y: Int16, _ w: Int16, _ h: Int16, _ color: UInt8) -> Void

@_silgen_name("arduino_ssd1306_fill_rect")
public func arduino_ssd1306_fill_rect(_ x: Int16, _ y: Int16, _ w: Int16, _ h: Int16, _ color: UInt8) -> Void

@_silgen_name("arduino_ssd1306_draw_circle")
public func arduino_ssd1306_draw_circle(_ x: Int16, _ y: Int16, _ r: Int16, _ color: UInt8) -> Void

@_silgen_name("arduino_ssd1306_fill_circle")
public func arduino_ssd1306_fill_circle(_ x: Int16, _ y: Int16, _ r: Int16, _ color: UInt8) -> Void

@_silgen_name("arduino_ssd1306_width")
public func arduino_ssd1306_width() -> Int16

@_silgen_name("arduino_ssd1306_height")
public func arduino_ssd1306_height() -> Int16