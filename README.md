# ArduinoSwift

**ArduinoSwift** is an experimental toolchain that lets you write **Arduino firmware in Swift** using **Embedded Swift**, while still relying on the **official Arduino cores, bootloaders, and Arduino CLI** (no forks, no patching).

This project is **research‑oriented**, **unstable**, and **not production‑ready**. The goal is exploration: understanding how far Swift can go on real microcontrollers.

---

## What ArduinoSwift is

ArduinoSwift is composed of:

- A **command‑line tool written in C** (build orchestration + staging)
- A **Swift runtime layer** designed for embedded environments
- A minimal **C/C++ bridge** that exposes Arduino APIs to Swift
- The **official Arduino toolchain** (`arduino-cli`, cores, linker, uploader)

You write the firmware logic in Swift. Arduino remains responsible for everything else.

**No Arduino core is forked.**  
**No bootloader is replaced.**  
**No vendor toolchain is modified.**

---

## What ArduinoSwift is NOT

- ❌ Not a reimplementation of Arduino in Swift
- ❌ Not a Swift‑only toolchain
- ❌ Not a simulator
- ❌ Not production‑ready

This project intentionally stays **close to real hardware**.

---

## Current status

- 🚧 Actively developed
- 🧪 Experimental and unstable
- 🧰 Multi‑board via `boards.json` (e.g. Due, Uno R4 Minima)
- ⚠️ Breaking changes are expected

---

## High‑level architecture

1. You write application logic in **Swift**
2. Swift is compiled with **Embedded Swift** into a single `.o` object
3. ArduinoSwift stages required shims + bridge sources into a sketch directory
4. `arduino-cli` builds the final firmware using the official core
5. The resulting binary is uploaded normally

Swift and Arduino are linked **at the object level**, not through hacks or core patches.

---

## Swift ↔ Arduino integration

- Swift never runs inside ISRs (keep it explicit and predictable)
- Hardware interaction goes through explicit C ABI bridges
- Libraries can be:
  - Swift‑only
  - Arduino‑only (C/C++)
  - Mixed Swift + Arduino C/C++ bridges

The build system stages bridge sources safely and keeps compilation deterministic.

---

## Configuration

Your project uses a `config.json` to declare:

- Which **board** you’re targeting
- Which **Swift libs** should be compiled into the Swift object
- Which **Arduino (C/C++) libs** must be compiled by `arduino-cli`

### Example `config.json`

```json
{
  "board": "Due",
  "lib": ["I2C", "Button", "SSD1306"],
  "arduino_lib": ["SSD1306Ascii"]
}
```

### Fields

#### `board`

A key that must exist in `boards.json` (tool/runtime), providing:

- `fqbn` (Arduino Fully Qualified Board Name)
- `swift_target`
- `cpu`
- optional flags (per board) to keep ABI/toolchain consistent

#### `lib` (Swift libraries)

List of Swift libraries to include in the Swift compilation step.

Resolution order (case‑insensitive):
1. Tool/runtime Swift libs: `tools/arduino-swift/swift/libs/<Lib>`
2. Project-local Swift libs: `<project>/libs/<Lib>`

These Swift sources are appended to the `swiftc` invocation and compiled into the single `.o`.

#### `arduino_lib` (Arduino C/C++ libraries)

List of Arduino libraries that **must be discovered and compiled by Arduino CLI** from the user’s sketchbook / installed platforms.

- These are **NOT copied** into the staged sketch (to avoid duplicate compilation).
- They are expected to be found by Arduino’s library discovery mechanism (as if you were compiling a normal sketch).

Typical use case:
- A Swift wrapper (in `lib`) calls a small bridge `.cpp` that uses a third‑party Arduino library.
- That third‑party library lives in your Arduino sketchbook (`~/Documents/Arduino/libraries`) or inside the installed platform package.

---

## Example (Swift)

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

## Tool usage

```bash
arduino-swift build
arduino-swift upload
arduino-swift monitor
```

Internally, the tool orchestrates:

- `swiftc` (Embedded Swift) → produces `ArduinoSwiftApp.o`
- `arduino-cli compile` → compiles Arduino core + Arduino libs + links Swift object
- `arduino-cli upload` / serial monitor tooling as configured

---

## Project layout (typical)

- `tools/arduino-swift/` — the C CLI tool + runtimes
- `tools/arduino-swift/swift/core/` — Swift core runtime
- `tools/arduino-swift/swift/libs/` — built-in Swift libs
- `usage/` — example project (your firmware)
  - `config.json`
  - `main.swift`
  - `libs/` (optional project-local Swift libs)
  - build output directories created by the tool

---

## Design principles

- Real Swift on real hardware
- No Arduino core forks
- Deterministic builds (staged sketch dir)
- Configuration over convention
- Explicit over implicit
- Correctness over convenience

---

## Why this exists

ArduinoSwift exists to explore:

- Embedded Swift viability
- Swift ABI and C interop on constrained environments
- Alternative firmware architectures
- Safer, more expressive embedded code

It is intentionally **low‑level**, **honest**, and **unforgiving**.

---

## Disclaimer

This project is experimental and intended for:

- Research
- Learning
- Exploration
- Toolchain experimentation

Use at your own risk.

---

## License

To be defined.
