# Arduino Swift

**Arduino Swift** is an experimental toolchain that allows you to write Arduino applications in **Swift**, using **Embedded Swift**, while still relying on the official Arduino core, bootloaders, and toolchain underneath.

This project is **under active development** and should be considered **unstable**. APIs, structure, and behavior may change at any time.

---

## What this project is

Arduino Swift is composed of:

- A **command-line tool written in C**
- A **Swift runtime layer** that runs on microcontrollers
- A thin **C/C++ bridge** that connects Swift with the Arduino core

The goal is to let you write your firmware logic entirely in **Swift**, while Arduino CLI, cores, and upload mechanisms remain untouched.

---

## Current status

- 🚧 Work in progress
- 🚫 Not production ready
- 🔧 Focused on experimentation and research
- 🧪 Tested mainly with Arduino Due and ARM-based boards

---

## How it works (high level)

1. You write your application logic in Swift
2. Swift is compiled with **Embedded Swift** into an object file
3. Arduino CLI builds the final firmware, linking the Swift object together with the Arduino core
4. The firmware is uploaded normally using Arduino tools

---

## Example (Swift)

```swift
import ArduinoRuntime

let led = PIN.builtin

let button = Button(5, onPress: {
    led.toggle()
})

ArduinoRuntime.add(button)
ArduinoRuntime.run()
```

---

## Tool usage

```bash
arduino-swift build
arduino-swift upload
arduino-swift monitor
```

The tool internally uses `arduino-cli` and `swiftc` (Embedded Swift).

---

## Design goals

- Use real Swift on microcontrollers
- Avoid Arduino core forks
- Keep the build pipeline transparent
- Favor simplicity over features

---

## Disclaimer

This project is experimental and intended for research, learning, and exploration.

---

## License

To be defined.
