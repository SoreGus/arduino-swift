# ArduinoSwift

**ArduinoSwift** is an experimental toolchain that lets you write **Arduino firmware in Swift** using **Embedded Swift**, while still relying on the **official Arduino cores, bootloaders, and Arduino CLI** (no forks, no patching).

This project is **research-oriented**, **unstable**, and **not production-ready**. The goal is exploration: understanding how far Swift can go on real microcontrollers.

---

## Quick start

From your firmware project directory (the one that contains `config.json` and `main.swift`):

```bash
# Build (Swift -> .o, then Arduino CLI compile/link)
../tools/arduino-swift/arduino-swift build

# Upload using the artifacts produced by build
../tools/arduino-swift/arduino-swift upload

# Convenience (verify + build + upload)
../tools/arduino-swift/arduino-swift all
```

Common overrides:

```bash
# Force a specific swiftc
SWIFTC=/path/to/swiftc ../tools/arduino-swift/arduino-swift build

# Force a specific port (Serial boards)
PORT=/dev/cu.usbmodemXXXX ../tools/arduino-swift/arduino-swift upload
```

---

## What ArduinoSwift is

ArduinoSwift is composed of:

- A command-line tool written in C (build orchestration + staging)
- A Swift runtime layer designed for embedded environments
- A minimal C/C++ bridge that exposes Arduino APIs to Swift
- The official Arduino toolchain (`arduino-cli`, cores, linker, uploader)

You write the firmware logic in Swift. Arduino remains responsible for everything else.

**No Arduino core is forked.**  
**No bootloader is replaced.**  
**No vendor toolchain is modified.**

---

## What ArduinoSwift is NOT

- Not a reimplementation of Arduino in Swift
- Not a Swift-only toolchain
- Not a simulator
- Not production-ready

This project intentionally stays close to real hardware.

---

## Supported boards

Boards are selected by `config.json` (`"board": "..."`) and resolved through the tool's board database.

Currently used/tested:

| Board key (config.json) | Example FQBN | Notes |
|---|---|---|
| `Due` | `arduino:sam:arduino_due_x` | Cortex-M3 |
| `Minima` | `arduino:renesas_uno:minima` | UNO R4 Minima (Renesas RA4M1, Cortex-M4F). Upload is typically **DFU** (not a `/dev/cu.*` serial port). |
| `GigaR1` | `arduino:mbed_giga:giga` | Arduino GIGA R1 (STM32H7). Uses board options (cm7/cm4 split, security, etc.). |

> New boards are added by extending the tool's board database. The goal is that the **same pipeline** works for **Due, Minima, Giga, and future boards**.

---

## High-level build pipeline

1. You write application logic in Swift
2. Swift is compiled with Embedded Swift into a single object: `ArduinoSwiftApp.o`
3. ArduinoSwift stages required shims/bridges/libs into a temporary sketch workspace
4. `arduino-cli compile` builds the final firmware using the official core and links Swift object + Arduino objects
5. Upload happens via `arduino-cli upload` (serial / dfu / platform-specific)

Swift and Arduino are linked at the object level (no core patches).

---

## Project layout

### Tool layout (inside this repo)

- `tools/arduino-swift/arduino-swift` - the CLI tool (C)
- `tools/arduino-swift/swift/core/` - Swift core runtime
- `tools/arduino-swift/swift/libs/` - built-in Swift libraries
- `tools/arduino-swift/arduino/commom/` - common Arduino bridge sources used by the staged sketch
- `tools/arduino-swift/arduino/libs/<Lib>/*` - tool-shipped Arduino/C++ libraries (**flat layout**, no `/src`)

### Firmware project layout (your app)

```
your_firmware/
  config.json
  main.swift
  libs/                  (optional) project-local Swift libs
    SSD1306/
      SSD1306.swift
      ...
  build/                 (generated)
```

---

## Configuration (config.json)

Your firmware project declares configuration via a single JSON file:

- Which board to target
- Optional board options (needed on some platforms like GIGA)
- Which Swift libs should be compiled into the Swift object
- Which Arduino libs should be compiled by `arduino-cli`

### Schema

```json
{
  "board": "Due | Minima | GigaR1 | ...",
  "board_options": { "key": "value" },
  "lib": ["SwiftLibA", "SwiftLibB"],
  "arduino_lib": ["ArduinoLibA", "ArduinoLibB"]
}
```

### Fields

#### board

A key that must exist in the tool's board database. It defines at minimum:

- `fqbn` (Arduino Fully Qualified Board Name)
- `swift_target`
- `cpu` (e.g. `cortex-m3`, `cortex-m4`, `cortex-m7`)

#### board_options (optional)

Passed to both compile and upload:

- `arduino-cli compile --board-options`
- `arduino-cli upload --board-options`

This matters for boards like GIGA where you pick things like core split and security.

#### lib (Swift libraries)

List of Swift libraries to include in the `swiftc` compilation step.

Resolution order (case-insensitive):

1. Tool/runtime Swift libs: `tools/arduino-swift/swift/libs/<Lib>/...`
2. Project-local Swift libs: `<your_project>/libs/<Lib>/...`

These sources are appended to the `swiftc` invocation and compiled into a single `.o`.

#### arduino_lib (Arduino C/C++ libraries)

List of Arduino libraries that must be discovered and compiled by Arduino CLI using Arduino's normal library discovery:

- Your sketchbook libs (e.g. `~/Documents/Arduino/libraries`)
- Platform-bundled libs (inside installed cores)

Important rule:

- **User Arduino libs are NOT copied** into the staged sketch (to avoid duplicate compilation).

Typical use case:

- A Swift wrapper (in `lib`) calls a small bridge `.cpp` that depends on a third-party Arduino library (in `arduino_lib`).

---

## Examples: config.json per board

### Arduino Due (Due)

```json
{
  "board": "Due",
  "lib": ["I2C", "Button", "SSD1306"],
  "arduino_lib": ["SSD1306Ascii"]
}
```

### Arduino UNO R4 Minima (Minima)

```json
{
  "board": "Minima",
  "lib": ["I2C", "Button"],
  "arduino_lib": []
}
```

> Upload note (Minima): on many setups `arduino-cli board list` shows a DFU port like `1-1` (protocol `dfu`), not a `/dev/cu.*` serial device. Upload should use that DFU port value (or set `PORT=1-1`).

### Arduino GIGA R1 (GigaR1)

```json
{
  "board": "GigaR1",
  "board_options": {
    "target_core": "cm7",
    "split": "100_0",
    "security": "none"
  },
  "lib": ["I2C", "Button", "SSD1306"],
  "arduino_lib": ["SSD1306Ascii"]
}
```

---

## Tool libs vs user libs (critical)

There are three different "library worlds" involved:

### 1) Tool Swift libs (built-in)

- Location: `tools/arduino-swift/swift/libs/<Lib>/`
- Used by: `swiftc` (compiled into `ArduinoSwiftApp.o`)

### 2) Tool Arduino/C++ libs (built-in)

- Location: `tools/arduino-swift/arduino/libs/<Lib>/*` (flat, no `/src`)
- Used by: staged sketch build via `arduino-cli`
- These are copied into the staged sketch during the build step.

### 3) User Arduino libs (your sketchbook)

- Location: typically `~/Documents/Arduino/libraries/<Lib>/`
- Used by: `arduino-cli` library discovery
- Never copied by ArduinoSwift (avoids double compilation and hard-to-debug conflicts).

---

## Staging behavior (what changed)

ArduinoSwift builds in a deterministic workspace:

`<your_project>/build/sketch/`

During build, the tool:

- Copies bridge/shim sources into the sketch root
- Stages tool-provided libs under `build/sketch/libraries/<Lib>/...`
- Normalizes libraries into Arduino 1.5 format at build time: `build/sketch/libraries/<Lib>/src/*`

To guarantee bridge sources compile and link reliably (without depending on Arduino's library discovery):

- Bridge `.c/.cpp` files are promoted into the sketch root (prefixed with `__asw_<Lib>__...`)
- Shim headers are generated into the sketch root to satisfy `#include "X.h"` patterns.

This avoids "it builds on board A but not on board B" library discovery edge cases.

---

## Troubleshooting

### Upload: "Could not detect PORT" (especially UNO R4 Minima)

Run:

```bash
arduino-cli board list
```

If you see something like:

- Port: `1-1`
- Protocol: `dfu`
- Board: `Arduino UNO R4 Minima`

...then your upload port is not `/dev/cu.*`. It's the DFU identifier.

Workaround:

```bash
PORT=1-1 ../tools/arduino-swift/arduino-swift upload
```

### Build: weird link errors around `compiler.c.elf.extra_flags`

If the injected link flags contain spaces, they must be quoted correctly when passed as:

- `--build-property compiler.c.elf.extra_flags=...`

Arduino cores differ in how they expand these properties. Prefer a quoting approach that keeps the injected Swift object as a single argument.

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
