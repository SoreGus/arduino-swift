#!/usr/bin/env bash
set -euo pipefail

: '
verify.sh
---------
What this step does:
  1) Validates config.json + boards.json (board selection)
  2) Ensures arduino-cli + python3 exist
  3) Ensures the Arduino core for the selected board is installed (asks to install)
  4) Ensures an Embedded Swift capable swiftc exists:
     - Prefer $SWIFTC if provided
     - Else try swiftc in PATH
     - Else use swiftly as the source of truth to locate the active toolchain path
     - Else allow choosing an Xcode toolchain from /Library/Developer/Toolchains
  5) Writes build/env.sh and build/.swiftc_path
'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/config.json"
BOARDS="$ROOT_DIR/boards.json"

BUILD_DIR="$ROOT_DIR/build"
ENV_SH="$BUILD_DIR/env.sh"
SWIFTC_PATH_FILE="$BUILD_DIR/.swiftc_path"

PRINT_SH="$ROOT_DIR/print.sh"
LOG_FILE="$BUILD_DIR/verify.log"
: > "$LOG_FILE"

mkdir -p "$BUILD_DIR"

# ----------------------------- UI (shared) -----------------------------
# We prefer the shared UI helpers from ../print.sh.
# If it is missing, we provide a minimal fallback so verify.sh can still run.
if [[ -f "$PRINT_SH" ]]; then
  # shellcheck disable=SC1090
  source "$PRINT_SH"
else
  ce_title() { echo; echo "=================================================="; echo "$*"; echo "=================================================="; }
  ce_step() { echo; echo "=============================="; echo "==> STEP: $*"; echo "=============================="; }
  ce_info() { echo "INFO  $*"; }
  ce_ok()   { echo "OK    $*"; }
  ce_warn() { echo "WARN  $*" >&2; }
  ce_err()  { echo "ERR   $*" >&2; }
  ce_die()  { ce_err "$*"; exit 1; }
  ce_prompt_yn() {
    local q="${1:-Are you sure?}"
    local def="${2:-n}"
    local ans=""
    if [[ "$def" == "y" ]]; then printf "%s [Y/n]: " "$q"; else printf "%s [y/N]: " "$q"; fi
    if [[ -r /dev/tty ]]; then read -r ans </dev/tty || true; else read -r ans || true; fi
    case "$ans" in
      "" ) [[ "$def" == "y" ]] && return 0 || return 1 ;;
      Y|y|YES|Yes|yes ) return 0 ;;
      * ) return 1 ;;
    esac
  }
  run_cmd_bg_tee() {
    local log_file="$1"; local msg="$2"; shift 2
    ce_info "$msg"
    "$@" 2>&1 | tee -a "$log_file"
    return ${PIPESTATUS[0]}
  }
  run_cmd_tee() {
    local log_file="$1"; shift
    "$@" 2>&1 | tee -a "$log_file"
    return ${PIPESTATUS[0]}
  }
fi

need() {
  if command -v "$1" >/dev/null 2>&1; then
    ce_ok "Found $1"
  else
    ce_die "Missing dependency: $1"
  fi
}

# ----------------------------- Validate base deps -----------------------------

[[ -f "$CONFIG" ]] || ce_die "config.json not found"
[[ -f "$BOARDS" ]] || ce_die "boards.json not found"

need arduino-cli
need python3

# Make sure swiftly shims are visible in non-interactive scripts (macOS/Linux)
# This matches the approach used in Gustavo's working Embedded Swift projects.
export PATH="$HOME/.swiftly/bin:$PATH"

# ----------------------------- Read board config -----------------------------

BOARD="$(
python3 - <<PY
import json
cfg=json.load(open("$CONFIG","r"))
print(cfg.get("board",""))
PY
)"
[[ -n "$BOARD" ]] || ce_die 'config.json must contain: { "board": "..." }'

python3 - <<PY
import json, sys
boards=json.load(open("$BOARDS","r"))
b="$BOARD"
if b not in boards:
    print("ERR Invalid board:", b)
    print("    Allowed boards:", ", ".join(sorted(boards.keys())))
    sys.exit(1)
print("OK board =", b)
print("OK fqbn  =", boards[b]["fqbn"])
print("OK core  =", boards[b]["core"])
PY

FQBN="$(
python3 - <<PY
import json
boards=json.load(open("$BOARDS","r"))
print(boards["$BOARD"]["fqbn"])
PY
)"
CORE="$(
python3 - <<PY
import json
boards=json.load(open("$BOARDS","r"))
print(boards["$BOARD"]["core"])
PY
)"

# ----------------------------- Ensure Arduino core installed -----------------------------

run_cmd_bg_tee "$LOG_FILE" "Updating Arduino CLI core index..." arduino-cli core update-index || true

if arduino-cli core list | awk '{print $1}' | grep -qx "$CORE"; then
  ce_ok "Core already installed: $CORE"
else
  ce_warn "Core not installed: $CORE"
  if ce_prompt_yn "Install this core now? (arduino-cli core install '$CORE')" "n"; then
    run_cmd_bg_tee "$LOG_FILE" "Installing core $CORE..." arduino-cli core install "$CORE" || ce_die "Failed to install core: $CORE"
    ce_ok "Core installed: $CORE"
  else
    ce_die "Cannot proceed without core: $CORE"
  fi
fi

# ----------------------------- Embedded Swift detection -----------------------------

supports_embedded_swift() {
  local sc="$1"
  [[ -x "$sc" ]] || return 1

  # Reliable check (same idea as the working Due Bare Metal project):
  # Ask swiftc for the runtime resource directory for armv7-none-none-eabi
  # and verify that the Embedded Swift stdlib directory exists.
  local target="armv7-none-none-eabi"
  local resdir
  resdir="$("$sc" -print-target-info -target "$target" 2>/dev/null | awk -F'"' '/runtimeResourcePath/ {print $4; exit}')"

  [[ -n "$resdir" && -d "$resdir" && -d "$resdir/embedded" ]]
}

record_swiftc() {
  local sc="$1"
  echo "$sc" > "$SWIFTC_PATH_FILE"
  ce_ok "Embedded Swift swiftc found:"
  ce_ok "  $sc"
  ce_ok "Saved to: $SWIFTC_PATH_FILE"
}

# 1) SWIFTC env var (absolute or in PATH)
try_env_swiftc() {
  if [[ -n "${SWIFTC:-}" ]]; then
    if [[ -x "$SWIFTC" ]] && supports_embedded_swift "$SWIFTC"; then
      record_swiftc "$SWIFTC"; return 0
    fi
    if command -v "$SWIFTC" >/dev/null 2>&1; then
      local p; p="$(command -v "$SWIFTC")"
      if supports_embedded_swift "$p"; then
        record_swiftc "$p"; return 0
      fi
    fi
  fi
  return 1
}

# 2) swiftc in PATH
try_path_swiftc() {
  # Prefer the swiftly shim if present (common on macOS/Linux)
  if [[ -x "$HOME/.swiftly/bin/swiftc" ]]; then
    local p="$HOME/.swiftly/bin/swiftc"
    if supports_embedded_swift "$p"; then
      record_swiftc "$p"; return 0
    fi
  fi

  # Fallback: whatever swiftc is in PATH
  if command -v swiftc >/dev/null 2>&1; then
    local p
    p="$(command -v swiftc)"
    if supports_embedded_swift "$p"; then
      record_swiftc "$p"; return 0
    fi
  fi

  return 1
}

# 3) Swiftly as source of truth: ask swiftly where the active toolchain is
# This avoids guessing paths.
swiftly_active_toolchain_root() {
  # We attempt a few "introspection" commands because swiftly versions differ.
  # We keep this robust by trying multiple possibilities.
  local out

  # Attempt 1: `swiftly which swiftc` (some versions support `which`)
  if command -v swiftly >/dev/null 2>&1; then
    out="$(swiftly which swiftc 2>/dev/null || true)"
    if [[ -n "$out" && -x "$out" ]]; then
      echo "$out"
      return 0
    fi
  fi

  # Attempt 2: use the resolved swiftc in PATH after `swiftly use ...`
  if command -v swiftc >/dev/null 2>&1; then
    out="$(command -v swiftc)"
    if [[ -n "$out" && -x "$out" ]]; then
      echo "$out"
      return 0
    fi
  fi

  # Attempt 3: if swiftly has a "toolchain-path" / "path" / "current" style command (varies)
  if command -v swiftly >/dev/null 2>&1; then
    out="$(swiftly toolchain-path 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
      if [[ -x "$out/usr/bin/swiftc" ]]; then
        echo "$out/usr/bin/swiftc"
        return 0
      fi
    fi
    out="$(swiftly current 2>/dev/null || true)"
    # Not reliable to parse; keep as best-effort only.
  fi

  return 1
}

try_swiftly() {
  command -v swiftly >/dev/null 2>&1 || return 1

  if ! ce_prompt_yn "No Embedded Swift toolchain found. Install/enable swiftly main-snapshot now?" "n"; then
    return 1
  fi

  run_cmd_bg_tee "$LOG_FILE" "Installing/updating main-snapshot (swiftly)..." swiftly install main-snapshot || true
  run_cmd_bg_tee "$LOG_FILE" "Activating main-snapshot (swiftly)..." swiftly use main-snapshot || true

  # IMPORTANT: PATH may not update for this process, so we do NOT rely on just `swiftc`.
  # We ask swiftly (or re-resolve) to get the actual swiftc path.
  local sc=""
  sc="$(swiftly_active_toolchain_root || true)"
  if [[ -n "$sc" && -x "$sc" ]] && supports_embedded_swift "$sc"; then
    record_swiftc "$sc"
    return 0
  fi

  # If swiftly can't tell, fall back to scanning common toolchain locations (last resort).
  return 1
}

# 4) Toolchain scan (last resort fallback)
scan_toolchains_fallback() {
  local candidates=()

  if [[ -d "/Library/Developer/Toolchains" ]]; then
    while IFS= read -r -d '' p; do
      candidates+=("$p")
    done < <(find /Library/Developer/Toolchains -maxdepth 2 -type f -path "*/usr/bin/swiftc" -print0 2>/dev/null || true)
  fi

  # A couple of widely used swiftly storage locations (fallback only)
  local home="$HOME"
  local extra_dirs=(
    "$home/.local/share/swiftly/toolchains"
    "$home/Library/Application Support/swiftly/toolchains"
    "$home/.swiftly/toolchains"
  )
  for d in "${extra_dirs[@]}"; do
    if [[ -d "$d" ]]; then
      while IFS= read -r -d '' p; do
        candidates+=("$p")
      done < <(find "$d" -maxdepth 6 -type f -path "*/usr/bin/swiftc" -print0 2>/dev/null || true)
    fi
  done

  if (( ${#candidates[@]} > 0 )); then
    for c in "${candidates[@]}"; do
      if supports_embedded_swift "$c"; then
        record_swiftc "$c"
        return 0
      fi
    done
  fi

  return 1
}

# Try in order:
try_env_swiftc && FOUND=1 || FOUND=0
if [[ "$FOUND" -eq 0 ]]; then try_path_swiftc && FOUND=1 || true; fi
if [[ "$FOUND" -eq 0 ]]; then try_swiftly && FOUND=1 || true; fi
if [[ "$FOUND" -eq 0 ]]; then scan_toolchains_fallback && FOUND=1 || true; fi

if [[ "$FOUND" -eq 0 ]]; then
  ce_title "No Embedded Swift toolchain found"

  ce_info ""
  ce_info "Choose how you want to proceed:"
  ce_info "  1) Select an installed Xcode toolchain from /Library/Developer/Toolchains/"
  ce_info "  2) Cancel"
  ce_info ""

  if ! [[ -t 0 && -t 1 ]]; then
    ce_die "Non-interactive mode: cannot prompt for toolchain selection."
  fi

  while true; do
    read -r -p "Enter option [1-2]: " opt
    case "${opt:-}" in
      1)
        [[ -d "/Library/Developer/Toolchains" ]] || ce_die "/Library/Developer/Toolchains not found"

        toolchains=()
        while IFS= read -r line; do
          [[ -n "$line" ]] && toolchains+=("$line")
        done < <(ls -1 /Library/Developer/Toolchains/*.xctoolchain 2>/dev/null || true)
        [[ ${#toolchains[@]} -gt 0 ]] || ce_die "No toolchains found in /Library/Developer/Toolchains"

        ce_info ""
        ce_info "Toolchains:"
        for i in "${!toolchains[@]}"; do
          ce_info "  $((i+1))) ${toolchains[$i]}"
        done
        ce_info ""

        read -r -p "Select a toolchain number: " idx
        [[ "$idx" =~ ^[0-9]+$ ]] || ce_die "Invalid number"
        (( idx >= 1 && idx <= ${#toolchains[@]} )) || ce_die "Out of range"

        chosen="${toolchains[$((idx-1))]}/usr/bin/swiftc"
        [[ -x "$chosen" ]] || ce_die "swiftc not found in: $chosen"

        if supports_embedded_swift "$chosen"; then
          record_swiftc "$chosen"
          FOUND=1
          break
        else
          ce_warn "That toolchain's swiftc does NOT support Embedded Swift."
          ce_info ""
        fi
        ;;
      2)
        ce_die "Cancelled by user."
        ;;
      *)
        ce_info "Please enter 1 or 2."
        ;;
    esac
  done
fi

# ----------------------------- Write env file -----------------------------

SWIFTC_CHOSEN="$(cat "$SWIFTC_PATH_FILE")"

cat > "$ENV_SH" <<EOF
# Auto-generated by steps/verify.sh
export SWIFTC="$SWIFTC_CHOSEN"
export ARDUINO_BOARD="$BOARD"
export ARDUINO_FQBN="$FQBN"
export ARDUINO_CORE="$CORE"
EOF

ce_ok "Wrote environment file: $ENV_SH"
ce_ok "verify complete."
ce_info "Tip: other steps can load the environment with:"
ce_info "  source \"$ENV_SH\""
echo "Tip: other steps can load the environment with:" >> "$LOG_FILE"
echo "  source \"$ENV_SH\"" >> "$LOG_FILE"