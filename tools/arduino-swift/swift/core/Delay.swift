// Delay.swift
// Global delay(ms) helper.
// - If ArduinoRuntime has tickables, uses cooperative delay so items keep ticking.
// - Otherwise, uses plain arduino_delay_ms for minimal overhead.

@inline(__always)
public func delay(_ ms: U32) {
    if ms == 0 { return }

    if ArduinoRuntime.hasItems {
        ArduinoRuntime.delay(ms: ms)
    } else {
        arduino_delay_ms(ms)
    }
}