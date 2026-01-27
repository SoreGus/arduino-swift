// port_detect.h
//
// Serial port auto-detection helpers for ArduinoSwift commands.
//
// Why this exists:
// - Both `upload` and future commands may need to choose a serial port safely.
// - Host systems expose many pseudo-ports (Bluetooth, network, debug console).
// - We prefer USB serial ports and ignore known-bad ones.
//
// Policy:
// - Never return Bluetooth / "Incoming" / rfcomm / debug-console ports.
// - Prefer USB-like names: usbmodem, usbserial, ttyACM, ttyUSB.
// - When matching to a board, we try to match the board's FQBN or its base token.
//
// These helpers are heuristic by design. When auto-detection fails, users can
// always force the port via: PORT=/dev/xxx arduino-swift upload
//
// This code uses shell parsing for portability (macOS + Linux).
// Keep it simple and resilient.

#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int port_is_bad(const char* port);
int port_is_preferred_usb(const char* port);

// Extract base token from an FQBN:
//   "arduino:sam:arduino_due_x" -> "arduino_due_x"
//   "arduino:renesas_uno:unor4minima" -> "unor4minima"
void fqbn_base_token(const char* fqbn, char* out, size_t cap);

// Best-effort port detection for a given fqbn.
// Returns 1 on success and writes the port into `out`.
int detect_port_for_fqbn(const char* fqbn, char* out, size_t cap);

#ifdef __cplusplus
}
#endif
