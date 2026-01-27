// ArduinoSwiftShimBase.h
// C-ABI surface for Swift (COMMON / BASE).
//
// Rules:
// - ONLY truly universal Arduino APIs live here.
// - No Serial / Analog / IRQ / SPI here.
// - No board assumptions.
// - No logic in headers.
//
// This header should remain stable across all boards.

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ----------------------
// Digital (universal)
// ----------------------
void     arduino_pinMode(uint32_t pin, uint32_t mode);
void     arduino_digitalWrite(uint32_t pin, uint32_t value);
uint32_t arduino_digitalRead(uint32_t pin);

// ----------------------
// Timing (universal)
// ----------------------
void     arduino_delay_ms(uint32_t ms);
uint32_t arduino_millis(void);

// ----------------------
// Constants (universal)
// ----------------------
uint32_t arduino_builtin_led(void);
uint32_t arduino_mode_output(void);
uint32_t arduino_mode_input(void);
uint32_t arduino_mode_input_pullup(void);
uint32_t arduino_high(void);
uint32_t arduino_low(void);

// ----------------------
// Entry point exported by Swift
// ----------------------
void arduino_swift_main(void);

#ifdef __cplusplus
} // extern "C"
#endif