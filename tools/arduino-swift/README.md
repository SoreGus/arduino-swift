# ArduinoSwift

ArduinoSwift is an experimental toolchain that lets you write **Arduino firmware in Embedded Swift**, while still using the Arduino ecosystem (cores, boards, libraries, and `arduino-cli`) for building and uploading.

It is designed for developers who want **Swift-level safety and structure** on microcontrollers, without giving up existing Arduino libraries or hardware support.

---

## What ArduinoSwift Does

ArduinoSwift acts as a **bridge between Swift and Arduino**:

- Swift code is compiled with **Embedded Swift** into a single `.o` object
- Arduino C/C++ code (core + libraries) is compiled normally via `arduino-cli`
- Both worlds are **linked together** into a standard Arduino firmware
- Upload and serial monitoring are handled by `arduino-cli`

You write your application logic in Swift, and ArduinoSwift handles the rest.

---

## Project Structure

A minimal ArduinoSwift project looks like this:

```
your-project/
├─ config.json
├─ boards.json
├─ main.swift
├─ libs/                # (optional) project-local Swift libs
│  └─ SSD1306/
│     ├─ SSD1306.swift
│     ├─ SSD1306+ArduinoAPI.swift
│     ├─ SSD1306Bridge.h
│     └─ SSD1306Bridge.cpp
└─ build/               # generated
```

---

## config.json

`config.json` defines which board and libraries your project uses:

```json
{
  "board": "Due",
  "lib": ["I2C", "Button", "SSD1306"],
  "arduino_lib": ["SSD1306Ascii"]
}
```

### Fields

- **board**  
  Must match an entry in `boards.json`.

- **lib**  
  Swift libraries to include.
  These are resolved from:
  - `arduino-swift/swift/libs/<LIB>/`
  - or `<project>/libs/<LIB>/`

- **arduino_lib**  
  External Arduino libraries (installed via Arduino IDE or Library Manager).
  Default search path:
  ```
  ~/Documents/Arduino/libraries
  ```
  (can be overridden with `arduino_lib_dir`)

---

## Swift Libraries vs Arduino Libraries

ArduinoSwift deliberately separates responsibilities:

### Swift Libraries (`lib`)
- High-level APIs written in Swift
- Can include Swift files **and** C/C++ bridge files
- Example: `SSD1306.swift`

### Arduino Libraries (`arduino_lib`)
- Existing Arduino C/C++ libraries
- Copied verbatim into the build
- Force-compiled to avoid Arduino CLI heuristics
- Example: `SSD1306Ascii`

Most real integrations need **both**:
- Swift API (ergonomic, safe)
- Arduino library (hardware implementation)

---

## Bridging Pattern (Important)

To use an external Arduino library from Swift, the recommended pattern is:

1. **C/C++ bridge**
   - Wrap the Arduino library with plain C functions
   - Example: `SSD1306Bridge.h/.cpp`

2. **Swift C-ABI declarations**
   - Declare those functions with `@_silgen_name`
   - Example: `SSD1306+ArduinoAPI.swift`

3. **High-level Swift API**
   - Safe, idiomatic Swift wrapper
   - Example: `SSD1306.swift`

This keeps:
- Swift code clean
- ABI stable
- Arduino code untouched

---

## main.swift

Your entry point must be:

```swift
@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    // your code
}
```

Notes:
- Do **not** use `@main`
- No Foundation
- Avoid heap allocation unless you know what you're doing
- Prefer `StaticString`, fixed buffers, or C strings

---

## Commands

ArduinoSwift provides four main commands:

### Verify environment
```
arduino-swift verify
```
- Checks `arduino-cli`
- Checks Embedded Swift support
- Installs Arduino cores if needed

### Build
```
arduino-swift build
```
- Compiles Swift + Arduino
- Produces a standard Arduino firmware

### Upload
```
arduino-swift upload
```
- Auto-detects serial port
- Can be overridden with:
  ```
  PORT=/dev/cu.usbmodemXXXX arduino-swift upload
  ```

### Monitor
```
arduino-swift monitor
```
- Opens serial monitor
- Defaults to 115200 baud
- Override with:
  ```
  BAUD=9600 arduino-swift monitor
  ```

---

## Design Goals

- Deterministic builds (no Arduino CLI guessing)
- Explicit linking between Swift and C/C++
- Zero magic at runtime
- Full control over memory and symbols
- Arduino compatibility preserved

---

## Non-Goals

- Automatic Swift bindings for all Arduino libraries
- Hiding C/C++ entirely
- Dynamic memory abstractions
- Beginner-friendly abstractions

ArduinoSwift is a **systems-level tool**, not a replacement for Arduino IDE.

---

## Status

ArduinoSwift is experimental and evolving.
Breaking changes are expected.

If you understand:
- Swift ABI
- Embedded systems
- C/C++ toolchains
- Arduino internals

You are the target audience.

---

## License

MIT (unless stated otherwise in subcomponents)
