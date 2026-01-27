// I2C.cpp
// ArduinoSwift Core - I2C (Wire) C-ABI implementation
//
// IMPORTANT:
// - Swift must NOT run inside ISR.
// - ISRs must be short and must not call Serial, delay, malloc, etc.
// - We only buffer bytes and set flags in ISR.
// - Main context (Swift) consumes buffers/flags.
//
// This file is Arduino-API-only:
// - Includes <Arduino.h> and <Wire.h>
// - No board-specific registers here
// - Works across boards that implement Wire slave callbacks.

#include <Arduino.h>
#include <Wire.h>
#include "I2C.h"

// --------------------------------------------------
// Configurable capacities
// --------------------------------------------------

#ifndef ARDUINO_SWIFT_I2C_SLAVE_RX_CAP
#define ARDUINO_SWIFT_I2C_SLAVE_RX_CAP 128
#endif

#ifndef ARDUINO_SWIFT_I2C_SLAVE_TX_CAP
#define ARDUINO_SWIFT_I2C_SLAVE_TX_CAP 128
#endif

// --------------------------------------------------
// Slave state (ISR-shared)
// --------------------------------------------------

static volatile uint8_t  gI2CSlaveOnReceive = 0;
static volatile uint8_t  gI2CSlaveOnRequest = 0;

static volatile uint8_t  gI2CRxBuf[ARDUINO_SWIFT_I2C_SLAVE_RX_CAP];
static volatile uint32_t gI2CRxHead = 0;
static volatile uint32_t gI2CRxTail = 0;

static volatile uint8_t  gI2CTxBuf[ARDUINO_SWIFT_I2C_SLAVE_TX_CAP];
static volatile uint32_t gI2CTxLen = 0;

// --------------------------------------------------
// RX ring buffer helpers (ISR-safe by design)
// --------------------------------------------------

static inline uint32_t i2c_rx_count_unsafe(void) {
  uint32_t h = gI2CRxHead;
  uint32_t t = gI2CRxTail;
  if (h >= t) return h - t;
  return ARDUINO_SWIFT_I2C_SLAVE_RX_CAP - (t - h);
}

static inline void i2c_rx_push_unsafe(uint8_t b) {
  uint32_t next = (gI2CRxHead + 1u) % ARDUINO_SWIFT_I2C_SLAVE_RX_CAP;
  if (next == gI2CRxTail) return; // overflow -> drop
  gI2CRxBuf[gI2CRxHead] = b;
  gI2CRxHead = next;
}

static inline int32_t i2c_rx_pop_unsafe(void) {
  if (gI2CRxTail == gI2CRxHead) return -1;
  uint8_t v = gI2CRxBuf[gI2CRxTail];
  gI2CRxTail = (gI2CRxTail + 1u) % ARDUINO_SWIFT_I2C_SLAVE_RX_CAP;
  return (int32_t)v;
}

// --------------------------------------------------
// ISR callbacks
// --------------------------------------------------

static void i2c_onReceive_isr(int count) {
  gI2CSlaveOnReceive = 1;

  while (count-- > 0) {
    int v = Wire.read();
    if (v < 0) break;
    i2c_rx_push_unsafe((uint8_t)v);
  }
}

static void i2c_onRequest_isr(void) {
  gI2CSlaveOnRequest = 1;

  // In ISR context already. Main context updates TX under noInterrupts().
  uint32_t copyLen = gI2CTxLen;
  if (copyLen > ARDUINO_SWIFT_I2C_SLAVE_TX_CAP)
    copyLen = ARDUINO_SWIFT_I2C_SLAVE_TX_CAP;

  if (copyLen == 0) {
    Wire.write((uint8_t)0);
    return;
  }

  // Copy to a non-volatile temp (Wire.write wants a normal pointer)
  uint8_t tmp[ARDUINO_SWIFT_I2C_SLAVE_TX_CAP];
  for (uint32_t i = 0; i < copyLen; i++)
    tmp[i] = gI2CTxBuf[i];

  Wire.write(tmp, (size_t)copyLen);
}

// --------------------------------------------------
// C ABI exposed to Swift
// --------------------------------------------------

extern "C" {

// ============================================================
// I2C (Wire) - Master
// ============================================================

void arduino_i2c_begin(void) {
  Wire.begin();
}

void arduino_i2c_setClock(uint32_t hz) {
  Wire.setClock((unsigned long)hz);
}

void arduino_i2c_beginTransmission(uint8_t address) {
  Wire.beginTransmission((int)address);
}

uint32_t arduino_i2c_write_byte(uint8_t b) {
  return (uint32_t)Wire.write((uint8_t)b);
}

uint32_t arduino_i2c_write_buf(const uint8_t* data, uint32_t len) {
  if (!data || len == 0) return 0;
  return (uint32_t)Wire.write(data, (size_t)len);
}

uint8_t arduino_i2c_endTransmission(uint8_t sendStop) {
  return (uint8_t)Wire.endTransmission(sendStop ? true : false);
}

uint32_t arduino_i2c_requestFrom(uint8_t address, uint32_t quantity, uint8_t sendStop) {
  return (uint32_t)Wire.requestFrom(
    (int)address,
    (int)quantity,
    (int)(sendStop ? 1 : 0)
  );
}

int32_t arduino_i2c_available(void) {
  return (int32_t)Wire.available();
}

int32_t arduino_i2c_read(void) {
  return (int32_t)Wire.read();
}

// ============================================================
// I2C (Wire) - Slave
// ============================================================

void arduino_i2c_slave_begin(uint8_t address) {
  noInterrupts();
  gI2CRxHead = 0;
  gI2CRxTail = 0;
  gI2CTxLen = 0;
  gI2CSlaveOnReceive = 0;
  gI2CSlaveOnRequest = 0;
  interrupts();

  Wire.begin((int)address);
  Wire.onReceive(i2c_onReceive_isr);
  Wire.onRequest(i2c_onRequest_isr);
}

uint32_t arduino_i2c_slave_rx_available(void) {
  noInterrupts();
  uint32_t c = i2c_rx_count_unsafe();
  interrupts();
  return c;
}

int32_t arduino_i2c_slave_rx_read(void) {
  noInterrupts();
  int32_t v = i2c_rx_pop_unsafe();
  interrupts();
  return v;
}

uint32_t arduino_i2c_slave_rx_read_buf(uint8_t* out, uint32_t maxLen) {
  if (!out || maxLen == 0) return 0;

  noInterrupts();
  uint32_t n = 0;
  while (n < maxLen) {
    int32_t v = i2c_rx_pop_unsafe();
    if (v < 0) break;
    out[n++] = (uint8_t)v;
  }
  interrupts();
  return n;
}

void arduino_i2c_slave_rx_clear(void) {
  noInterrupts();
  gI2CRxHead = 0;
  gI2CRxTail = 0;
  interrupts();
}

void arduino_i2c_slave_set_tx(const uint8_t* data, uint32_t len) {
  noInterrupts();

  if (!data || len == 0) {
    gI2CTxLen = 0;
    interrupts();
    return;
  }

  if (len > ARDUINO_SWIFT_I2C_SLAVE_TX_CAP)
    len = ARDUINO_SWIFT_I2C_SLAVE_TX_CAP;

  for (uint32_t i = 0; i < len; i++)
    gI2CTxBuf[i] = data[i];

  gI2CTxLen = len;
  interrupts();
}

uint32_t arduino_i2c_slave_consume_onReceive(void) {
  noInterrupts();
  uint8_t v = gI2CSlaveOnReceive;
  gI2CSlaveOnReceive = 0;
  interrupts();
  return v ? 1u : 0u;
}

uint32_t arduino_i2c_slave_consume_onRequest(void) {
  noInterrupts();
  uint8_t v = gI2CSlaveOnRequest;
  gI2CSlaveOnRequest = 0;
  interrupts();
  return v ? 1u : 0u;
}

} // extern "C"