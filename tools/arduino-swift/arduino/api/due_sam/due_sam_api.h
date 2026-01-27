// due_sam_api.h
// ArduinoSwift API extensions for Arduino Due (SAM3X / ARDUINO_ARCH_SAM).
//
// This file declares additional C-ABI entrypoints beyond the BASE shim.
// Keep this layer focused on what is actually needed by Swift.
//
// Includes:
// - Analog
// - External Interrupts (flag-based polling)
// - Serial (basic printing)
//
// NOT included here (for now):
// - SPI (moves to libs/spi later)

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ----------------------
// Analog
// ----------------------
uint32_t arduino_analogRead(uint32_t pin);
void     arduino_analogReadResolution(uint32_t bits);
uint32_t arduino_analogMaxValue(void);

// ----------------------
// External Interrupts (flag-based)
// ----------------------
uint32_t arduino_irq_mode_low(void);
uint32_t arduino_irq_mode_change(void);
uint32_t arduino_irq_mode_rising(void);
uint32_t arduino_irq_mode_falling(void);
uint32_t arduino_irq_mode_high(void);

int32_t  arduino_digitalPinToInterrupt(uint32_t pin);

int32_t  arduino_irq_attach(uint32_t pin, uint32_t mode);
void     arduino_irq_detach(int32_t slot);
uint32_t arduino_irq_consume(int32_t slot);

// ----------------------
// Serial
// ----------------------
void arduino_serial_begin(uint32_t baud);
void arduino_serial_print_cstr(const char* s);
void arduino_serial_print_i32(int32_t v);
void arduino_serial_print_u32(uint32_t v);
void arduino_serial_print_f64(double v);

#ifdef __cplusplus
} // extern "C"
#endif