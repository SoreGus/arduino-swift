# ArduinoSwift Swift API (swift/)

This document describes the **Swift-side Core** shipped with ArduinoSwift (the `tools/arduino-swift/swift/` directory).

**Goal:** keep the Swift side **single-source** (one implementation) across boards (Due, R4 Minima, etc.) by talking only to a stable **C ABI** that is implemented on the Arduino side (`arduino/abi/<abi_name>/...`).

> **Rule:** Swift never imports Arduino headers directly.  
> Swift only calls `@_silgen_name(...)` functions declared in `swift/core/*ABI*.swift` or `swift/libs/*/*ABI*.swift`.

---

## Directory Layout

```
swift/
  core/
    ArduinoABI.swift
    PIN.swift
    AnalogPIN.swift
    Serial.swift
    Print.swift
    Delay.swift
    ArduinoRuntime.swift
    ASCII.swift

  libs/
    Button/
      Button.swift
    I2C/
      I2C.swift
      I2C+ArduinoABI.swift
```

### What goes where

- **`swift/core/`**
  - Board-agnostic Swift code used by every app.
  - Contains the **base ABI declarations** (`ArduinoABI.swift`) + small helpers and wrappers.
  - Must be safe with `-parse-as-library` (no top-level executable code).

- **`swift/libs/`**
  - Optional Swift libraries (Button, I2C, etc.) enabled per-project (via config).
  - Each lib may ship:
    - high-level Swift logic (`<Lib>.swift`)
    - optional ABI bridge declarations (`<Lib>+ArduinoABI.swift`) only when that lib is enabled

---

## The ABI boundary

The Swift side depends on a **stable C ABI contract** implemented by the Arduino-side core:

- Arduino side: `arduino/abi/base_abi.h` + `arduino/abi/<abi_name>/*`
- Swift side: `swift/core/ArduinoABI.swift` + `swift/libs/<Lib>/<Lib>+ArduinoABI.swift`

### Why this works for Due AND R4

Because Swift only relies on symbols like:

- `arduino_pinMode`, `arduino_digitalWrite`, `arduino_millis`, `arduino_serial_print_cstr`, etc.

As long as the Arduino core for the selected board exposes those **exact symbol names** (and behavior is compatible), Swift code does not change.

---

## swift/core overview

### `ArduinoABI.swift`
Declares the **base ABI** surface via `@_silgen_name`.

**Must contain only declarations**, no logic.

Example:

```swift
@_silgen_name("arduino_pinMode")
public func arduino_pinMode(_ pin: U32, _ mode: U32) -> Void
```

> Keep the set minimal. Add functions only when there is a clear common behavior across boards.

---

### `PIN.swift`
High-level digital pin wrapper:
- caches last configured mode to reduce redundant `pinMode` calls
- exposes helpers: `on()`, `off()`, `toggle()`, `pullup()`, etc.
- uses ABI constants: `arduino_high()`, `arduino_low()`, `arduino_mode_*()`

---

### `AnalogPIN.swift`
High-level analog wrapper:
- configures resolution once (`arduino_analogReadResolution`)
- caches `maxValue` via `arduino_analogMaxValue`
- provides normalized reading `[0.0, 1.0]`

**Important:** different boards may have different “recommended” resolutions.
- Keep a default (e.g., 12-bit), but allow caller override.

---

### `Serial.swift` + `Print.swift`
- `Serial` is the tiny “driver” wrapper over ABI functions:
  - `arduino_serial_begin`
  - `arduino_serial_print_cstr`
  - and numeric prints
- `Print.swift` provides global `print/println` helpers with auto-initialization.

**Rule:** keep printing ABI extremely small and stable. Prefer `print_cstr` + numbers.

---

### `ArduinoRuntime.swift` + `Delay.swift`
A minimal cooperative runtime:
- `ArduinoTickable` protocol
- `ArduinoRuntime.add(...)` + `tickAll()`
- `ArduinoRuntime.keepAlive()` loops calling `tickAll()` and delays
- `delay(ms:)` becomes cooperative when tickables exist

This is intentionally tiny and board-agnostic.

---

## swift/libs overview

### Button
- Pure Swift polling button built on `PIN`
- Integrates with `ArduinoRuntime` (tick-based)
- No extra ABI required

Enable by including the lib in project config.

---

### I2C
Split into:
- `I2C.swift` — pure Swift implementation (master + slave + packet + devices)
- `I2C+ArduinoABI.swift` — ABI declarations for I2C symbols

This keeps the core clean: if you don’t enable I2C, you don’t compile/link its ABI.

---

## Build & selection rules (Swift side)

ArduinoSwift builds a project by selecting:
- `swift/core/**/*.swift` (always)
- `swift/libs/<Lib>/**/*.swift` (only for enabled libs)

Then it compiles Swift into a single `.o` which is linked by Arduino CLI.

**Determinism rule:** The file set must be explicit (no “find whatever compiles” heuristics).

---

## Adding new ABI functions

### Step 1 — Add to Arduino base ABI or to a lib ABI

- If it’s universal and stable: add it to **base ABI**:
  - Arduino: `arduino/abi/base_abi.h`
  - Swift: `swift/core/ArduinoABI.swift`

- If it’s optional / peripheral-specific: add it to a **lib ABI**:
  - Arduino: `arduino/libs/<Lib>/<Lib>.h/.cpp`
  - Swift: `swift/libs/<Lib>/<Lib>+ArduinoABI.swift`

> Prefer “lib ABI” whenever possible to keep the base stable.

---

### Step 2 — Implement per board on Arduino side

Each board maps to one `<abi_name>`. That ABI implementation must provide the symbols.

- For base ABI symbols: implement in `arduino/abi/<abi_name>/<abi_name>_shim.cpp`
- For runtime shims: `arduino/abi/<abi_name>/<abi_name>_runtime_support.c`
- For lib ABI symbols: implement in `arduino/libs/<Lib>/<Lib>.cpp`, with optional overrides under:
  - `arduino/libs/<Lib>/abi/<abi_name>/...`

---

### Step 3 — Keep Swift code board-agnostic

Swift should not check board name, MCU family, or `#if` by board.
If behavior differs:
- fix it on the Arduino side, or
- split into a board-specific Arduino implementation, or
- (last resort) create a separate ABI feature flag + safe fallback in Swift

---

## ABI compatibility checklist (Due vs R4)

When validating a new board ABI implementation, confirm:

1. **Symbol names match** exactly (C ABI).
2. **Integer widths** are compatible:
   - Swift uses `UInt32`, `Int32`, `UInt8` in the ABI.
3. **Timing semantics**:
   - `arduino_millis()` is monotonic (wraparound ok).
   - `arduino_delay_ms(ms)` blocks roughly ms.
4. **Digital I/O semantics**:
   - `arduino_high()` / `arduino_low()` match the core.
   - `pinMode` modes match: input/output/pullup.
5. **Serial printing**:
   - `print_cstr` expects a null-terminated C string.
6. **Analog**:
   - `analogReadResolution(bits)` behaves consistently.
   - `analogMaxValue()` returns the max for the chosen resolution.

If these are satisfied, the same Swift core should run on both boards without changes.

---

## Non-goals (Swift side)

- No board detection logic.
- No direct MCU register access.
- No Arduino header imports.
- No per-board `#if` in Swift (unless truly unavoidable).

---

*Document generated for the ArduinoSwift refactor plan (January 2026).*
