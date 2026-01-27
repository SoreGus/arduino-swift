# ArduinoSwift

**ArduinoSwift** is an experimental toolchain that lets you write **Arduino firmware in Swift** using **Embedded Swift**, while still relying on the **official Arduino cores, bootloaders, and Arduino CLI** (no forks, no patches).

This is a **research / learning project**. Expect breaking changes.

---

## TL;DR

- You write your app logic in **Swift**
- ArduinoSwift compiles it with **Embedded Swift** into a single `.o`
- ArduinoSwift stages required bridge code + libraries into a temporary sketch
- `arduino-cli` builds the final firmware with the official core/toolchain
- Upload/monitor works as usual

---

## Repository layout

```
ArduinoSwift/
├─ tools/
│  └─ arduino-swift/              # the CLI tool (C) + runtimes
│     ├─ arduino/                 # Arduino-side libraries shipped with the tool (optional per lib)
│     ├─ swift/                   # Swift runtime + Swift libraries
│     ├─ boards.json              # board definitions (FQBN, swift target, cpu, etc.)
│     └─ ...
└─ usage/
   ├─ config.json                 # project config (board + libs)
   ├─ libs/                       # project-local Swift libs (optional)
   ├─ main.swift                  # your firmware entry
   └─ ...                         # example project
```

---

## What ArduinoSwift is

ArduinoSwift is composed of:

- A **command-line tool written in C** (build orchestration and staging)
- A **Swift runtime layer** designed for embedded environments
- A minimal **C/C++ bridge** that exposes Arduino APIs to Swift
- The **official Arduino toolchain** (arduino-cli, cores, linker, uploader)

You write firmware logic in Swift. Arduino remains responsible for everything else.

✅ No Arduino core is forked  
✅ No bootloader is replaced  
✅ No vendor toolchain is modified

---

## What ArduinoSwift is NOT

- ❌ Not a reimplementation of Arduino in Swift
- ❌ Not a Swift-only toolchain
- ❌ Not a simulator
- ❌ Not production-ready

This project intentionally stays close to real hardware.

---

## Supported boards (currently)

Board support is driven by `tools/arduino-swift/boards.json`.

Example entries:

```json
{
  "Due": {
    "fqbn": "arduino:sam:arduino_due_x",
    "core": "arduino:sam",
    "swift_target": "armv7-none-none-eabi",
    "cpu": "cortex-m3"
  },
  "R4Minima": {
    "fqbn": "arduino:renesas_uno:minima",
    "core": "arduino:renesas_uno",
    "swift_target": "armv7em-none-none-eabi",
    "cpu": "cortex-m4",
    "float_abi": "hard",
    "fpu": "fpv4-sp-d16"
  }
}
```

Notes:

- For **R4 Minima (Cortex-M4F)**, ArduinoSwift forces the Arduino core build flags to match Swift’s object ABI (avoiding common VFP mismatch linker errors).
- If you add new boards, keep the definition minimal and explicit: `fqbn`, `core`, `swift_target`, `cpu` (+ optional float settings if needed).

---

## Prerequisites

- **arduino-cli** installed and working
- Board platform installed via Arduino CLI (e.g. `arduino:sam`, `arduino:renesas_uno`, etc.)
- An **Embedded Swift** toolchain / snapshot (Swift nightly) compatible with your targets

> Tip: make sure `arduino-cli compile` works for the target board *before* using ArduinoSwift.

---

## Quick start (usage example)

Go to the example project:

```bash
cd usage
```

Build:

```bash
../tools/arduino-swift/bin/arduino-swift build
```

Upload:

```bash
../tools/arduino-swift/bin/arduino-swift upload
```

Serial monitor:

```bash
../tools/arduino-swift/bin/arduino-swift monitor
```

(Exact binary location may vary depending on how you build/install the tool.)

---

## Project configuration (`usage/config.json`)

ArduinoSwift is configuration-driven.

Minimal example:

```json
{
  "board": "Due",
  "libs": ["I2C", "Button"]
}
```

For a project that also uses a project-local Swift lib:

```json
{
  "board": "R4Minima",
  "libs": ["I2C", "Button", "SSD1306"]
}
```

### How libraries are resolved

When you list a lib in `config.json`, ArduinoSwift:

1. Looks for the Swift library in:
   - `tools/arduino-swift/swift/libs/<Lib>` (tool-shipped)
   - `usage/libs/<Lib>` (project-local)
2. Compiles all `.swift` files into the final Swift object
3. If the lib contains C/C++ bridge files, ArduinoSwift stages them for Arduino compilation
4. If there is a matching Arduino-side library shipped with the tool (`tools/arduino-swift/arduino/libs/<Lib>`), it is staged too

Additionally, **user Arduino libs** are expected to be discovered from the user sketchbook by Arduino CLI (ArduinoSwift does not copy them to avoid double compilation).

---

## Firmware entry (Swift)

Your `usage/main.swift` is appended to the Swift compile step.

A typical entry looks like this:

```swift
@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    Serial.begin(115200)
    Serial.print("Swift main boot\n")

    let led = PIN.builtin
    led.output()
    led.off()

    let button = Button(
        5,
        onPress: {
            led.toggle()
            Serial.print("Button pressed -> LED toggled\n")
        }
    )

    ArduinoRuntime.add(button)
    ArduinoRuntime.keepAlive()
}
```

---

## High-level build pipeline

1. Collect Swift sources:
   - `tools/arduino-swift/swift/core/*.swift`
   - selected Swift libs (`swift/libs` and/or `usage/libs`)
   - `usage/main.swift`
2. Compile with `swiftc` (Embedded Swift) into a single `.o`
3. Stage a temporary Arduino sketch directory:
   - copy bridge `.c/.cpp/.h` files into `sketch/libraries/<Lib>/src`
   - promote bridge sources to sketch root (to guarantee compile/link)
   - generate shim headers in sketch root (to satisfy `#include "X.h"`)
4. Run `arduino-cli compile` with build properties:
   - inject the Swift `.o` into the final link
   - adjust flags for board/ABI compatibility when needed
5. Upload using the normal Arduino upload toolchain

---

## Design principles

- Real Swift on real hardware
- No Arduino core forks
- Deterministic and transparent builds
- Configuration over convention
- Explicit over implicit
- Correctness over convenience

---

## Known quirks / tips

### UNO R4 (Renesas) + I2C OLED (SSD1306, etc.)
If you see random pixels / partially-cleared screens on power-up, it is often an I2C timing/timeout issue on the Renesas `Wire` implementation when bus conditions are “slow” (level shifters, pull-ups, etc.). A common fix is to set a larger `Wire` timeout and use 100 kHz:

```cpp
#if defined(ARDUINO_ARCH_RENESAS)
  Wire.setWireTimeout(10000);
  Wire.setClock(100000);
  delay(10);
#endif
```

---

## Why this exists

ArduinoSwift exists to explore:

- Embedded Swift viability
- Swift ABI and C interop in constrained environments
- Alternative firmware architectures
- Safer, more expressive embedded code on microcontrollers

It is intentionally low-level and honest about the constraints.

---

## Disclaimer

This project is experimental and intended for:

- Research
- Learning
- Toolchain experimentation

Use at your own risk.

---

## License

TBD.
