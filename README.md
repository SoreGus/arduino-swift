# ArduinoSwift

ArduinoSwift is a **minimal, modern Swift runtime for Arduino boards** using **Embedded Swift**.
The goal is to let you write Arduino programs in Swift with a clean, expressive API — without
losing the simplicity of the Arduino mental model.

This project is intentionally **low-level, explicit, and hackable**.

---

## ✨ Features

- Embedded Swift (no Foundation, no heavy runtime)
- Works with `arduino-cli`
- Clean C ↔ Swift ABI boundary
- High-level Swift APIs:
  - `PIN`, `AnalogPIN`
  - `Button` with `onPress` / `onRelease`
  - `Serial.print(...)`
  - Cooperative runtime (`ArduinoRuntime`)
- No hidden magic
- No blocking delays (runtime-safe)

---

## 📦 Project Structure

```
ArduinoSwift/
├── swift/
│   ├── App.swift
│   ├── ArduinoAPI.swift
│   ├── ArduinoRuntime.swift
│   ├── PIN.swift
│   ├── AnalogPIN.swift
│   ├── Button.swift
│   └── Serial.swift
│
├── steps/
│   ├── verify.sh
│   ├── compile.sh
│   ├── upload.sh
│   └── monitor.sh
│
├── boards.json
├── config.json
└── README.md
```

---

## 🚀 Quick Start

### 1. Verify toolchain

```bash
./run.sh verify
```

This checks:
- `arduino-cli`
- Embedded Swift toolchain
- Board configuration

---

### 2. Compile

```bash
./run.sh compile
```

This:
- Compiles Swift → `.o` using Embedded Swift
- Generates Arduino sketch
- Links everything via `arduino-cli`

---

### 3. Upload

```bash
./run.sh upload
```

---

### 4. Monitor Serial

```bash
./run.sh monitor
```

---

## 🧠 Minimal Example

```swift
@_cdecl("arduino_swift_main")
public func arduino_swift_main() -> Void {
    Serial.begin(115200)
    Serial.print("Boot OK\n")

    let led = PIN.builtin
    led.off()

    let button = Button(
        5,
        onPress: {
            led.toggle()
            Serial.print("pressed\n")
        },
        onRelease: {
            Serial.print("released\n")
        }
    )

    ArduinoRuntime.add(button)

    ArduinoRuntime.keepAlive()
}
```

---

## ⏱ Cooperative Delays (Important)

**Never use `arduino_delay_ms()` directly inside logic loops.**

Instead:

```swift
ArduinoRuntime.delay(ms: 500)
```

This keeps:
- Buttons responsive
- Runtime ticking
- No blocking

Example:

```swift
ArduinoRuntime.keepAlive {
    ArduinoRuntime.delay(ms: 500)
    Serial.print("tick\n")
}
```

---

## 🔘 Button API

```swift
let button = Button(
    5,
    onPress: {
        Serial.print("pressed\n")
    },
    onRelease: {
        Serial.print("released\n")
    }
)

button.enable()
button.disable()

if button.isOn() {
    // button currently pressed
}
```

- Default mode: `INPUT_PULLUP`
- Debounced
- Runtime-driven (no busy loops)

---

## 🔌 Serial API

```swift
Serial.begin(115200)

Serial.print("Hello")
Serial.print(42)
Serial.print(3.14)
Serial.print("\n")
```

No `println` by design.

---

## 🧩 Design Principles

- **Swift stays in Swift**
- **ISRs stay in C**
- No Swift code ever runs inside interrupts
- All events are dispatched cooperatively
- Explicit > implicit
- Simple > clever

---

## ⚠️ Supported Boards

- Arduino Due (SAM3X) ✅
- Other ARM boards: possible with minor tweaks
- AVR: **not supported** (Embedded Swift limitation)

---

## 🛠 Requirements

- macOS or Linux
- `arduino-cli`
- Embedded Swift toolchain (Swift 6+ snapshot)
- ARM-based Arduino board

---

## 📜 License

MIT — do whatever you want, just don’t pretend you wrote it 😉

---

## ❤️ Philosophy

This project is for people who:
- Like understanding what runs on the metal
- Want modern language ergonomics
- Hate opaque frameworks
- Enjoy building their own tools

Have fun 🚀
