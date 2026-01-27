# ArduinoSwift Core (`arduino/`)

This document describes the **Arduino-side Core** shipped with ArduinoSwift (the `tools/arduino-swift/arduino/` directory).

Goal:
- Make **Embedded Swift + Arduino CLI** builds deterministic.
- Keep **board-specific** behavior isolated.
- Provide a **stable C ABI** surface that Swift can call.

> **Design rule:** Swift talks only to a stable C ABI.  
> Each ArduinoSwift **API** implements that ABI (and may add optional extensions).  
> `common/` is *always* identical across boards.

---

## Directory layout

```
arduino/
  common/
    sketch.ino
    Bridge.cpp

  api/
    due_sam/
      due_sam_api.h
      due_sam_shim.cpp
      due_sam_runtime_support.c

    renesas_r4/
      renesas_r4_api.h
      renesas_r4_shim.cpp
      renesas_r4_runtime_support.c

  libs/
    I2C/
      I2C.h
      I2C.cpp
      api/
        <api_name>/
          <override files...>
```

### What goes where

- **`common/`**
  - Must contain only files that are identical for all supported boards.
  - No board-specific `#if` logic.
  - Keeps the Arduino CLI sketch structure stable.

- **`api/<api_name>/`**
  - One directory per **API** (example: `due_sam`, `renesas_r4`).
  - Contains everything that may differ across boards/cores/toolchains:
    - `<api_name>_api.h`  
      The C ABI contract *for this API*.  
      **Rule:** the “Base ABI” section must match across all APIs.
    - `<api_name>_shim.cpp`  
      Implements the ABI functions declared in `<api_name>_api.h` using the Arduino core.
    - `<api_name>_runtime_support.c`  
      Embedded Swift runtime shims required for that toolchain/platform. Prefer pure C and avoid `Arduino.h`.

- **`libs/`**
  - Arduino-side libraries used by Swift libraries (I2C, SPI, display drivers, etc.).
  - Libraries are **API-agnostic by default**, but can override per API when required.
  - Overrides live in `libs/<lib>/api/<api_name>/` and are copied **on top of** the default files.

---

## Why “api” (and not “arch”)

Arduino ecosystems blur “board”, “core”, and “architecture” boundaries. Some behaviors evolve per board/core even with similar MCUs.

Using a single concept — **API** — keeps the tool simple and scalable:

- A **board selects one API**.
- The **API owns all conditional behavior** (shims, runtime symbols, quirks).
- `common/` remains completely static and deterministic.

This avoids premature “arch vs board” splitting while still allowing growth (e.g. `renesas_r4_wifi` later).

---

## Board → API mapping (`boards.json`)

ArduinoSwift uses `boards.json` in the tool root. Each supported board must specify:

- `fqbn` : the Arduino CLI fully-qualified board name
- `api` : which ArduinoSwift API directory to use (e.g. `due_sam`)
- `swift_target` : Swift target triple for Embedded Swift

Example:

```json
{
  "Due": {
    "fqbn": "arduino:sam:arduino_due_x",
    "api": "due_sam",
    "swift_target": "armv7-none-none-eabi"
  },
  "R4_Minima": {
    "fqbn": "arduino:renesas_uno:unor4minima",
    "api": "renesas_r4",
    "swift_target": "thumbv7em-none-none-eabi"
  }
}
```

**Rule:** if a board is not present in `boards.json`, the build must fail fast with a clear error.

---

## Build-time staging rules (high level)

During `cmd_build`, the tool prepares a temporary Arduino sketch workspace (example: `<project>/build/sketch`).  
Staging must be **deterministic** and must not rely on Arduino CLI heuristics.

### Step A — Stage ArduinoSwift Core: `common/`
Copy into the staged sketch root:

- `arduino/common/sketch.ino`
- `arduino/common/Bridge.cpp`

### Step B — Stage the selected API
Select the API from `boards.json` (`api = "<api_name>"`) and copy into the staged sketch root:

- `arduino/api/<api_name>/<api_name>_api.h`
- `arduino/api/<api_name>/<api_name>_shim.cpp`
- `arduino/api/<api_name>/<api_name>_runtime_support.c`

> This is where the C ABI and runtime symbols come from.

### Step C — Stage ArduinoSwift tool libraries (internal)
For each internal library requested by the build (example: `I2C`), stage it into:

- `build/sketch/libraries/<LibName>/...`

Procedure:

1. Copy default library files:
   - `arduino/libs/<lib>/*` → `build/sketch/libraries/<lib>/`
2. If exists, copy overrides on top:
   - `arduino/libs/<lib>/api/<api_name>/*` → `build/sketch/libraries/<lib>/` (overwrite)

### Step D — Stage user Arduino libraries (external)
ArduinoSwift can stage user libraries selected in `config.json` via `arduino_lib`.

- Default user Arduino libraries directory:
  - `$HOME/Documents/Arduino/libraries`
- Override via `config.json`:
  - `"arduino_lib_dir": "/path/to/Arduino/libraries"`

For each `"arduino_lib": ["LibA", "LibB"]`, the tool finds the matching folder under `arduino_lib_dir` (case-insensitive) and copies it into:

- `build/sketch/libraries/<ResolvedLibFolder>/`

> External user Arduino libs are staged as-is.  
> If a user library needs API-specific behavior, prefer putting the glue into ArduinoSwift internal `libs/<lib>/api/<api_name>/` (recommended), or ship separate user libraries per API if unavoidable.

### Step E — Compile Swift and inject the `.o`
The Swift side compiles into a single object file (example: `ArduinoSwiftApp.o`), then Arduino CLI links it by injecting it into:

- `compiler.c.elf.extra_flags` (or equivalent Arduino CLI build property)

---

## `common/`: required files

### `common/sketch.ino`
Arduino CLI requires a `.ino` inside the sketch folder. This file must **not** define `setup()` or `loop()`.

### `common/Bridge.cpp`
Owns `setup()` and `loop()` and transfers control to Swift via a required symbol:

- `arduino_swift_main()`

Optional weak hooks may be supported:
- `arduino_swift_setup()`
- `arduino_swift_loop()`

`Bridge.cpp` must remain identical across boards.

---

## `api/<api_name>/`: required files and naming

For an API named `<api_name>`, create:

- `api/<api_name>/<api_name>_api.h`
  - Contains the ABI contract for that API.
  - **Structure rule:** keep two clearly separated sections:
    1. **Base ABI**: identical across all APIs (same function names + signatures).
    2. **API extensions (optional)**: extra features only supported by that API.

- `api/<api_name>/<api_name>_shim.cpp`
  - Implements everything required by `<api_name>_api.h`.
  - Should include only Arduino public headers needed (`Arduino.h`, and optional core libs like `Wire.h`, etc. depending on what the ABI exposes).

- `api/<api_name>/<api_name>_runtime_support.c`
  - Provides Embedded Swift runtime symbols required by that platform/toolchain.
  - Prefer pure C, avoid including `Arduino.h`.
  - Keep it “linker-driven”: only provide what the linker complains about.

### What belongs in the Base ABI vs API extensions

Put in the **Base ABI** only what is stable across all supported boards.

Usually safe in the Base ABI:
- `pinMode`, `digitalWrite`, `digitalRead`
- `millis`, `delay`
- basic constants (`HIGH/LOW`, `INPUT/OUTPUT`, `LED_BUILTIN`)

Usually better as API extensions (or moved into `libs/`):
- interrupt attach/detach APIs (behavior varies per core)
- advanced timers, DMA, power/clock control
- complex peripherals (SPI, I2C, UART) if the cores diverge
  - Prefer `libs/` for these when possible (ex: I2C is a `libs/I2C` library)

---

## `libs/`: overrides

A library can remain API-agnostic until proven otherwise.

- Default implementation:
  - `libs/<lib>/<lib>.h`
  - `libs/<lib>/<lib>.cpp`

- Optional overrides:
  - `libs/<lib>/api/<api_name>/*`

**Override rule:** stage defaults first, then stage overrides over the top.  
This supports patching a single file for an API without duplicating the entire library.

---

## Practical checklist: adding a new API (new boards later)

1. Pick a new API name (example: `renesas_r4_wifi`).
2. Add a board entry to `boards.json` with:
   - `fqbn`, `api`, `swift_target`
3. Create:
   - `arduino/api/<api_name>/<api_name>_api.h`
   - `arduino/api/<api_name>/<api_name>_shim.cpp`
   - `arduino/api/<api_name>/<api_name>_runtime_support.c`
4. If an internal library needs changes:
   - Add override files under `arduino/libs/<lib>/api/<api_name>/`
5. Ensure `cmd_build` stages:
   - `common/` + selected `api/<api_name>/` + required `libs/` (+ overrides) deterministically.

---

## Non-goals of the Arduino Core

- The Arduino Core is not responsible for detecting boards or installing Arduino cores.
  - Arduino CLI handles that.
- The Arduino Core should not embed complex per-board logic in `common/`.
  - Keep differences isolated in `api/<api_name>/`.

---

*ArduinoSwift Core architecture (refactor plan, January 2026).*
