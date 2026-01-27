// Bridge.cpp
// Minimal Arduino entry bridge -> Swift.
//
// Common:
// - Does not assume Serial/SPI/IRQ/Analog exist.
// - Defines setup()/loop() here so the sketch remains deterministic.
// - Swift owns the lifecycle via arduino_swift_main(), with optional setup/loop hooks.

#include <Arduino.h>
#include "ArduinoSwiftShimBase.h"

extern "C" {

// Required: Swift must provide this (via @_cdecl("arduino_swift_main")).
void arduino_swift_main(void);

// Optional hooks (Swift may provide or not).
void arduino_swift_setup(void) __attribute__((weak));
void arduino_swift_loop(void)  __attribute__((weak));

} // extern "C"

static bool gSwiftDidStart = false;

void setup() {
  if (gSwiftDidStart) return;
  gSwiftDidStart = true;

  if (arduino_swift_setup) {
    arduino_swift_setup();
  }

  // If arduino_swift_main() never returns, Swift owns the system (OK).
  arduino_swift_main();
}

void loop() {
  // If Swift provides a cooperative loop hook, call it.
  // No delay/yield here: Swift decides if/when to yield.
  if (arduino_swift_loop) {
    arduino_swift_loop();
  }
}