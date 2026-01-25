// arduino/ArduinoSwiftShim.cpp
// Implements the C-ABI surface using Arduino core libs.
// Swift must not run in ISR, so I2C slave callbacks only set flags/buffers.

#include <Arduino.h>
#include <Wire.h>
#include <SPI.h>
#include "ArduinoSwiftShim.h"

// ----------------------------------------------
// Analog resolution helpers (board-agnostic-ish)
// ----------------------------------------------
static uint32_t gAnalogBits = 10;

static uint32_t analogMaxFromBits(uint32_t bits) {
  if (bits == 0) return 0;
  if (bits >= 31) return 0x7FFFFFFFu;
  return ((uint32_t)1u << bits) - 1u;
}

// --------------------------------------------------
// IRQ slots (flag-based)
// --------------------------------------------------
#ifndef ARDUINO_SWIFT_IRQ_SLOTS
#define ARDUINO_SWIFT_IRQ_SLOTS 8
#endif

struct SwiftIrqSlot {
  uint8_t  used;
  uint8_t  irqNumber;
  volatile uint8_t fired;
};

static SwiftIrqSlot gSlots[ARDUINO_SWIFT_IRQ_SLOTS] = {};

static void irq0() { gSlots[0].fired = 1; }
static void irq1() { gSlots[1].fired = 1; }
static void irq2() { gSlots[2].fired = 1; }
static void irq3() { gSlots[3].fired = 1; }
static void irq4() { gSlots[4].fired = 1; }
static void irq5() { gSlots[5].fired = 1; }
static void irq6() { gSlots[6].fired = 1; }
static void irq7() { gSlots[7].fired = 1; }

static void (*const gHandlers[ARDUINO_SWIFT_IRQ_SLOTS])() = {
  irq0, irq1, irq2, irq3, irq4, irq5, irq6, irq7
};

// --------------------------------------------------
// I2C Slave (ISR-safe buffering)
// --------------------------------------------------
#ifndef ARDUINO_SWIFT_I2C_SLAVE_RX_CAP
#define ARDUINO_SWIFT_I2C_SLAVE_RX_CAP 128
#endif

#ifndef ARDUINO_SWIFT_I2C_SLAVE_TX_CAP
#define ARDUINO_SWIFT_I2C_SLAVE_TX_CAP 128
#endif

static volatile uint8_t  gI2CSlaveOnReceive = 0;
static volatile uint8_t  gI2CSlaveOnRequest = 0;

static volatile uint8_t  gI2CRxBuf[ARDUINO_SWIFT_I2C_SLAVE_RX_CAP];
static volatile uint32_t gI2CRxHead = 0;
static volatile uint32_t gI2CRxTail = 0;

static volatile uint8_t  gI2CTxBuf[ARDUINO_SWIFT_I2C_SLAVE_TX_CAP];
static volatile uint32_t gI2CTxLen = 0;

static inline uint32_t i2c_rx_count_unsafe(void) {
  uint32_t h = gI2CRxHead;
  uint32_t t = gI2CRxTail;
  if (h >= t) return (h - t);
  return (ARDUINO_SWIFT_I2C_SLAVE_RX_CAP - (t - h));
}

static inline void i2c_rx_push_unsafe(uint8_t b) {
  uint32_t next = (gI2CRxHead + 1u) % ARDUINO_SWIFT_I2C_SLAVE_RX_CAP;
  if (next == gI2CRxTail) {
    return; // overflow -> drop
  }
  gI2CRxBuf[gI2CRxHead] = b;
  gI2CRxHead = next;
}

static inline int32_t i2c_rx_pop_unsafe(void) {
  if (gI2CRxTail == gI2CRxHead) return -1;
  uint8_t v = gI2CRxBuf[gI2CRxTail];
  gI2CRxTail = (gI2CRxTail + 1u) % ARDUINO_SWIFT_I2C_SLAVE_RX_CAP;
  return (int32_t)v;
}

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

  // Snapshot TX buffer atomically (Wire.write happens outside critical section).
  uint8_t tmp[ARDUINO_SWIFT_I2C_SLAVE_TX_CAP];
  uint32_t copyLen = 0;

  noInterrupts();
  copyLen = gI2CTxLen;
  if (copyLen > ARDUINO_SWIFT_I2C_SLAVE_TX_CAP) copyLen = ARDUINO_SWIFT_I2C_SLAVE_TX_CAP;
  for (uint32_t i = 0; i < copyLen; i++) tmp[i] = gI2CTxBuf[i];
  interrupts();

  if (copyLen == 0) {
    Wire.write((uint8_t)0);
    return;
  }

  Wire.write(tmp, (size_t)copyLen);
}

extern "C" {

// ----------------------
// Digital
// ----------------------
void arduino_pinMode(uint32_t pin, uint32_t mode) {
  pinMode((uint8_t)pin, (uint8_t)mode);
}
void arduino_digitalWrite(uint32_t pin, uint32_t value) {
  digitalWrite((uint8_t)pin, (uint8_t)value);
}
uint32_t arduino_digitalRead(uint32_t pin) {
  return (uint32_t)digitalRead((uint8_t)pin);
}

// ----------------------
// Timing
// ----------------------
void arduino_delay_ms(uint32_t ms) {
  delay((unsigned long)ms);
}
uint32_t arduino_millis(void) {
  return (uint32_t)millis();
}

// ----------------------
// Analog
// ----------------------
uint32_t arduino_analogRead(uint32_t pin) {
  return (uint32_t)analogRead((uint32_t)pin);
}

void arduino_analogReadResolution(uint32_t bits) {
  if (bits == 0) bits = 10;
  gAnalogBits = bits;

  // Only some cores implement analogReadResolution (Due/SAM, many ARM cores).
  // AVR typically doesn't. Guard to keep portability.
  #if defined(ARDUINO_ARCH_SAM) || defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_STM32) || defined(ARDUINO_ARCH_RP2040) || defined(ESP32)
    analogReadResolution((int)bits);
  #else
    (void)bits;
  #endif
}

uint32_t arduino_analogMaxValue(void) {
  return analogMaxFromBits(gAnalogBits);
}

// ----------------------
// Constants
// ----------------------
uint32_t arduino_builtin_led(void) {
#ifdef LED_BUILTIN
  return (uint32_t)LED_BUILTIN;
#else
  return 13;
#endif
}

uint32_t arduino_mode_output(void)       { return (uint32_t)OUTPUT; }
uint32_t arduino_mode_input(void)        { return (uint32_t)INPUT; }
uint32_t arduino_mode_input_pullup(void) { return (uint32_t)INPUT_PULLUP; }
uint32_t arduino_high(void)              { return (uint32_t)HIGH; }
uint32_t arduino_low(void)               { return (uint32_t)LOW; }

// ----------------------
// IRQ
// ----------------------
int32_t arduino_digitalPinToInterrupt(uint32_t pin) {
  int irq = digitalPinToInterrupt((uint8_t)pin);
  return (int32_t)irq;
}

uint32_t arduino_irq_mode_low(void)     { return (uint32_t)LOW; }
uint32_t arduino_irq_mode_change(void)  { return (uint32_t)CHANGE; }
uint32_t arduino_irq_mode_rising(void)  { return (uint32_t)RISING; }
uint32_t arduino_irq_mode_falling(void) { return (uint32_t)FALLING; }
uint32_t arduino_irq_mode_high(void)    { return (uint32_t)HIGH; }

int32_t arduino_irq_attach(uint32_t pin, uint32_t mode) {
  int irq = digitalPinToInterrupt((uint8_t)pin);

#ifdef NOT_AN_INTERRUPT
  if (irq == NOT_AN_INTERRUPT) return -1;
#endif
  if (irq < 0) return -1;

  for (int i = 0; i < ARDUINO_SWIFT_IRQ_SLOTS; i++) {
    if (!gSlots[i].used) {
      gSlots[i].used = 1;
      gSlots[i].irqNumber = (uint8_t)irq;
      gSlots[i].fired = 0;

      // Use the pin-based overload when available (most cores), but this works too:
      attachInterrupt((uint8_t)irq, gHandlers[i], (int)mode);
      return (int32_t)i;
    }
  }
  return -1;
}

void arduino_irq_detach(int32_t slot) {
  if (slot < 0 || slot >= (int32_t)ARDUINO_SWIFT_IRQ_SLOTS) return;
  if (!gSlots[slot].used) return;

  detachInterrupt((int)gSlots[slot].irqNumber);
  gSlots[slot].used = 0;
  gSlots[slot].fired = 0;
  gSlots[slot].irqNumber = 0;
}

uint32_t arduino_irq_consume(int32_t slot) {
  if (slot < 0 || slot >= (int32_t)ARDUINO_SWIFT_IRQ_SLOTS) return 0;
  if (!gSlots[slot].used) return 0;

  noInterrupts();
  uint8_t v = gSlots[slot].fired;
  gSlots[slot].fired = 0;
  interrupts();

  return (uint32_t)(v ? 1u : 0u);
}

// ----------------------
// Serial
// ----------------------
void arduino_serial_begin(uint32_t baud) {
  Serial.begin((unsigned long)baud);
}

void arduino_serial_print_cstr(const char* s) {
  if (!s) return;
  Serial.print(s);
}

void arduino_serial_print_i32(int32_t v) {
  Serial.print((long)v);
}

void arduino_serial_print_u32(uint32_t v) {
  Serial.print((unsigned long)v);
}

void arduino_serial_print_f64(double v) {
  Serial.print(v);
}

// ----------------------
// I2C (Wire) - Master
// ----------------------
void arduino_i2c_begin(void) {
  Wire.begin();
}

void arduino_i2c_setClock(uint32_t hz) {
  Wire.setClock((unsigned long)hz);
}

void arduino_i2c_beginTransmission(uint8_t address) {
  Wire.beginTransmission(address);
}

uint32_t arduino_i2c_write_byte(uint8_t b) {
  return (uint32_t)Wire.write(b);
}

uint32_t arduino_i2c_write_buf(const uint8_t* data, uint32_t len) {
  if (!data || len == 0) return 0;
  return (uint32_t)Wire.write(data, (size_t)len);
}

uint8_t arduino_i2c_endTransmission(uint8_t sendStop) {
  return (uint8_t)Wire.endTransmission(sendStop ? true : false);
}

uint32_t arduino_i2c_requestFrom(uint8_t address, uint32_t quantity, uint8_t sendStop) {
  return (uint32_t)Wire.requestFrom((int)address, (int)quantity, (int)(sendStop ? 1 : 0));
}

int32_t arduino_i2c_available(void) {
  return (int32_t)Wire.available();
}

int32_t arduino_i2c_read(void) {
  return (int32_t)Wire.read();
}

// ----------------------
// I2C (Wire) - Slave
// ----------------------
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

  if (len > ARDUINO_SWIFT_I2C_SLAVE_TX_CAP) len = ARDUINO_SWIFT_I2C_SLAVE_TX_CAP;
  for (uint32_t i = 0; i < len; i++) gI2CTxBuf[i] = data[i];
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

// ----------------------
// SPI
// ----------------------
void arduino_spi_begin(void) { SPI.begin(); }
void arduino_spi_end(void)   { SPI.end(); }

void arduino_spi_beginTransaction(uint32_t clockHz, uint8_t bitOrder, uint8_t dataMode) {
  SPI.beginTransaction(SPISettings((unsigned long)clockHz, (BitOrder)bitOrder, (uint8_t)dataMode));
}

void arduino_spi_endTransaction(void) {
  SPI.endTransaction();
}

uint8_t arduino_spi_transfer(uint8_t v) {
  return SPI.transfer(v);
}

uint32_t arduino_spi_transfer_buf(uint8_t* data, uint32_t len) {
  if (!data || len == 0) return 0;
  SPI.transfer(data, (size_t)len);
  return len;
}

} // extern "C"