// arduino/Bridge.cpp
//
// Arduino entry bridge -> Swift.
//
// Goal:
// - Give Swift full control.
// - We do NOT force any delay/yield here.
// - If Swift wants cooperative scheduling, it can implement arduino_swift_loop() and return quickly.
// - If Swift wants total control, it can implement arduino_swift_main() that never returns.

#include <Arduino.h>
#include "ArduinoSwiftShim.h"

extern "C" {

// Required: your Swift side must provide this (via @_cdecl("arduino_swift_main")).
void arduino_swift_main(void);

// Optional hooks (Swift may provide or not)
void arduino_swift_setup(void) __attribute__((weak));
void arduino_swift_loop(void)  __attribute__((weak));

} // extern "C"

static bool gSwiftDidStart = false;

void setup() {
  // Start Swift exactly once.
  if (!gSwiftDidStart) {
    gSwiftDidStart = true;

    // Optional: Swift setup hook (if you prefer splitting setup/loop).
    if (arduino_swift_setup) {
      arduino_swift_setup();
    }

    // Main Swift entry.
    // If arduino_swift_main() never returns -> Swift owns the whole system (OK).
    arduino_swift_main();
  }
}

void loop() {
  // If Swift provides a cooperative loop hook, call it.
  // No delay/yield here: Swift decides if/when to yield.
  if (arduino_swift_loop) {
    arduino_swift_loop();
  }
}