# Arduino Swift

**Arduino Swift** is an experimental toolchain that allows you to write **Arduino firmware in Swift**, using **Embedded Swift**, while continuing to rely on the **official Arduino cores, bootloaders, and Arduino CLI** without modification.

This project is **research‑oriented**, **unstable**, and **not production‑ready**. Its purpose is exploration: understanding how far Swift can be pushed on microcontrollers.

---

## What Arduino Swift is

Arduino Swift is composed of:

- A **command‑line tool written in C** (the build system and glue)
- A **Swift runtime layer** designed for embedded environments
- A minimal **C/C++ bridge** that exposes Arduino APIs to Swift
- The **official Arduino toolchain** (arduino‑cli, cores, linker, uploader)

You write firmware logic in Swift. Arduino remains responsible for everything else.

No Arduino core is forked.
No bootloader is replaced.
No vendor toolchain is modified.

---

## What Arduino Swift is NOT

- ❌ Not a reimplementation of Arduino in Swift  
- ❌ Not a Swift‑only toolchain  
- ❌ Not a simulator  
- ❌ Not production‑ready  

This project intentionally stays **close to real hardware**.

---

## Current status

- 🚧 Actively developed
- 🧪 Experimental and unstable
- 🧠 Focused on research and learning
- 🧰 ARM‑focused (tested mainly on Arduino Due and similar boards)
- ⚠️ Breaking changes are expected

---

## High‑level architecture

1. You write application logic in **Swift**
2. Swift is compiled with **Embedded Swift** into a single `.o` file
3. Arduino Swift copies required shims and libraries into a sketch directory
4. `arduino-cli` builds the final firmware
5. The resulting binary is uploaded normally

Swift and Arduino are linked **at the object level**, not through hacks or patches.

---

## Swift ↔ Arduino integration

- Swift never runs inside ISRs
- All hardware interaction goes through explicit C ABI bridges
- Arduino libraries may be:
  - Fully implemented in C/C++
  - Header‑only
  - Swift‑only
  - Mixed Swift + Arduino C/C++

The build system automatically includes **all `.c` / `.cpp` files** found in selected Arduino libraries and safely ignores empty ones.

---

## Configuration‑driven libraries

Your project declares which libraries are used:

```json
{
  "board": "Due",
  "lib": ["I2C", "Button"]
}
```

From this:

- Swift libraries are compiled into the Swift object
- Matching Arduino libraries (if present) are copied and compiled
- Libraries may be empty on the Arduino side — this is valid

No hardcoded filenames.
No assumptions about entrypoints.
Everything is directory‑driven.

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

- `swiftc` (Embedded Swift)
- `arduino-cli`
- The official Arduino core and linker

---

## Design principles

- Real Swift on real hardware
- No Arduino core forks
- Deterministic and transparent builds
- Configuration over convention
- Explicit over implicit
- Correctness over convenience

---

## Why this exists

Arduino Swift exists to explore:

- Embedded Swift viability
- Swift ABI and C interop in constrained environments
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
