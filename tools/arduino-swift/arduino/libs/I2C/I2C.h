// arduino/libs/I2C/I2C.h
// C-ABI surface for I2C (Wire) used by Swift.
// Logic is implemented in I2C.c.

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

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

#ifdef __cplusplus
}
#endif