// arduino/ArduinoSwiftShim.h
// C-ABI surface for Swift. No logic here.

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ----------------------
// Digital
// ----------------------
void     arduino_pinMode(uint32_t pin, uint32_t mode);
void     arduino_digitalWrite(uint32_t pin, uint32_t value);
uint32_t arduino_digitalRead(uint32_t pin);

// ----------------------
// Timing
// ----------------------
void     arduino_delay_ms(uint32_t ms);
uint32_t arduino_millis(void);

// ----------------------
// Analog
// ----------------------
uint32_t arduino_analogRead(uint32_t pin);
void     arduino_analogReadResolution(uint32_t bits);
uint32_t arduino_analogMaxValue(void);

// ----------------------
// Constants
// ----------------------
uint32_t arduino_builtin_led(void);
uint32_t arduino_mode_output(void);
uint32_t arduino_mode_input(void);
uint32_t arduino_mode_input_pullup(void);
uint32_t arduino_high(void);
uint32_t arduino_low(void);

// ----------------------
// External Interrupts (flag-based)
// ----------------------
uint32_t arduino_irq_mode_low(void);
uint32_t arduino_irq_mode_change(void);
uint32_t arduino_irq_mode_rising(void);
uint32_t arduino_irq_mode_falling(void);
uint32_t arduino_irq_mode_high(void);

int32_t  arduino_irq_attach(uint32_t pin, uint32_t mode);
void     arduino_irq_detach(int32_t slot);
uint32_t arduino_irq_consume(int32_t slot);

int32_t  arduino_digitalPinToInterrupt(uint32_t pin);

// ----------------------
// Serial
// ----------------------
void arduino_serial_begin(uint32_t baud);
void arduino_serial_print_cstr(const char* s);
void arduino_serial_print_i32(int32_t v);
void arduino_serial_print_u32(uint32_t v);
void arduino_serial_print_f64(double v);

// ----------------------
// SPI (for later)
// ----------------------
void     arduino_spi_begin(void);
void     arduino_spi_end(void);

void     arduino_spi_beginTransaction(uint32_t clockHz, uint8_t bitOrder, uint8_t dataMode);
void     arduino_spi_endTransaction(void);

uint8_t  arduino_spi_transfer(uint8_t v);
uint32_t arduino_spi_transfer_buf(uint8_t* data, uint32_t len);

// ----------------------
// Entry point exported by Swift
// ----------------------
void arduino_swift_main(void);

#ifdef __cplusplus
}
#endif