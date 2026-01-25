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
// I2C (Wire) - Master
// ----------------------
void     arduino_i2c_begin(void);
void     arduino_i2c_setClock(uint32_t hz);

void     arduino_i2c_beginTransmission(uint8_t address);
uint32_t arduino_i2c_write_byte(uint8_t b);
uint32_t arduino_i2c_write_buf(const uint8_t* data, uint32_t len);

uint8_t  arduino_i2c_endTransmission(uint8_t sendStop);

uint32_t arduino_i2c_requestFrom(uint8_t address, uint32_t quantity, uint8_t sendStop);
int32_t  arduino_i2c_available(void);
int32_t  arduino_i2c_read(void);

// ----------------------
// I2C (Wire) - Slave (ISR-safe, polled by Swift)
// ----------------------
void     arduino_i2c_slave_begin(uint8_t address);

uint32_t arduino_i2c_slave_rx_available(void);
int32_t  arduino_i2c_slave_rx_read(void);
uint32_t arduino_i2c_slave_rx_read_buf(uint8_t* out, uint32_t maxLen);
void     arduino_i2c_slave_rx_clear(void);

void     arduino_i2c_slave_set_tx(const uint8_t* data, uint32_t len);

uint32_t arduino_i2c_slave_consume_onReceive(void);
uint32_t arduino_i2c_slave_consume_onRequest(void);

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