// I2C.h
// ArduinoSwift Core - I2C (Wire) C-ABI
//
// Goal:
// - Expose a stable C ABI for Swift.
// - Keep ISR work minimal: only buffer data + set flags.
// - Swift (or user code) must poll/consume flags and buffers from main context.
//
// Notes:
// - Master API wraps standard Wire calls.
// - Slave API uses Wire.onReceive / Wire.onRequest and buffers data safely.
// - This file is intentionally Arduino-API-only (portable across cores that support Wire).

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// I2C (Wire) - Master
// ============================================================

void     arduino_i2c_begin(void);
void     arduino_i2c_setClock(uint32_t hz);

void     arduino_i2c_beginTransmission(uint8_t address);
uint32_t arduino_i2c_write_byte(uint8_t b);
uint32_t arduino_i2c_write_buf(const uint8_t* data, uint32_t len);

uint8_t  arduino_i2c_endTransmission(uint8_t sendStop);

uint32_t arduino_i2c_requestFrom(uint8_t address, uint32_t quantity, uint8_t sendStop);
int32_t  arduino_i2c_available(void);
int32_t  arduino_i2c_read(void);

// ============================================================
// I2C (Wire) - Slave (ISR-safe, polled by Swift)
// ============================================================
//
// Design:
// - ISR: receive bytes -> push to RX ring buffer; set "onReceive" flag.
// - ISR: request -> write prepared TX buffer to Wire; set "onRequest" flag.
// - Main: Swift polls flags and RX buffer; Swift sets TX buffer ahead of requests.

void     arduino_i2c_slave_begin(uint8_t address);

// RX (from master -> slave)
uint32_t arduino_i2c_slave_rx_available(void);
int32_t  arduino_i2c_slave_rx_read(void);
uint32_t arduino_i2c_slave_rx_read_buf(uint8_t* out, uint32_t maxLen);
void     arduino_i2c_slave_rx_clear(void);

// TX (slave -> master)
void     arduino_i2c_slave_set_tx(const uint8_t* data, uint32_t len);

// Flags (edge-triggered, cleared by consume)
uint32_t arduino_i2c_slave_consume_onReceive(void);
uint32_t arduino_i2c_slave_consume_onRequest(void);

#ifdef __cplusplus
} // extern "C"
#endif