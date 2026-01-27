// ArduinoSwiftShimBase.cpp
// COMMON / BASE implementation.
//
// Notes:
// - Only uses <Arduino.h>.
// - No Serial / Analog / IRQ / SPI here.

#include <Arduino.h>
#include "ArduinoSwiftShim.h"

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
// Constants
// ----------------------
uint32_t arduino_builtin_led(void) {
#ifdef LED_BUILTIN
  return (uint32_t)LED_BUILTIN;
#else
  return 13u;
#endif
}

uint32_t arduino_mode_output(void)       { return (uint32_t)OUTPUT; }
uint32_t arduino_mode_input(void)        { return (uint32_t)INPUT; }
uint32_t arduino_mode_input_pullup(void) { return (uint32_t)INPUT_PULLUP; }
uint32_t arduino_high(void)              { return (uint32_t)HIGH; }
uint32_t arduino_low(void)               { return (uint32_t)LOW; }

} // extern "C"