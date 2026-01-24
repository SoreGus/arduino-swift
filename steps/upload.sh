#!/usr/bin/env bash
set -euo pipefail

: '
upload.sh
---------
What this step does:
  1) Reads the selected board fqbn from config.json / boards.json
  2) Detects a serial port via "arduino-cli board list" (or uses $PORT if set)
  3) Uploads the already-built artifacts from build/arduino_build
'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/config.json"
BOARDS="$ROOT_DIR/boards.json"

PRINT_SH="$ROOT_DIR/print.sh"
BUILD="$ROOT_DIR/build"
LOG_FILE="$BUILD/upload.log"
mkdir -p "$BUILD"
: > "$LOG_FILE"

# ----------------------------- UI (shared) -----------------------------
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
  run_cmd_tee() { local lf="$1"; shift; "$@" 2>&1 | tee -a "$lf"; return ${PIPESTATUS[0]}; }
  run_cmd_bg_tee() { local lf="$1"; local msg="$2"; shift 2; ce_info "$msg"; "$@" 2>&1 | tee -a "$lf"; return ${PIPESTATUS[0]}; }
fi

need() {
  if command -v "$1" >/dev/null 2>&1; then
    ce_ok "Found $1"
  else
    ce_die "Missing dependency: $1"
  fi
}

need arduino-cli
need python3

ce_title "Uploading"
ce_info "Log: $LOG_FILE"

SKETCH="$BUILD/sketch"
ARD_BUILD="$BUILD/arduino_build"

[[ -d "$ARD_BUILD" ]] || ce_die "Build output not found. Run: ./run.sh compile"

BOARD="$(
python3 - <<PY
import json
cfg=json.load(open("$CONFIG","r"))
print(cfg["board"])
PY
)"

FQBN="$(
python3 - <<PY
import json
boards=json.load(open("$BOARDS","r"))
print(boards["$BOARD"]["fqbn"])
PY
)"

ce_info "Board: $BOARD"
ce_info "FQBN:  $FQBN"

PORT="${PORT:-}"
if [[ -z "$PORT" ]]; then
  # Prefer a port that matches the configured board FQBN.
  # On macOS, `arduino-cli board list` may list Bluetooth/console ports first,
  # so we must filter for the actual Arduino device.
  PORT="$(
  python3 - <<PY
import json, subprocess, sys
fqbn_target = "$FQBN".strip()

try:
    out = subprocess.check_output(["arduino-cli","board","list","--format","json"], text=True)
    data = json.loads(out)
except Exception:
    data = None

# arduino-cli output can be:
#  - a list of entries
#  - a dict like {"ports": [...]} (varies by CLI version)
items = []
if isinstance(data, list):
    items = data
elif isinstance(data, dict):
    # try common keys
    for k in ("ports", "boards", "items"):
        v = data.get(k)
        if isinstance(v, list):
            items = v
            break

candidates = []
for item in items:
    if not isinstance(item, dict):
        continue
    port_info = item.get("port")
    if isinstance(port_info, dict):
        port = port_info.get("address")
    else:
        port = item.get("address") if isinstance(item.get("address"), str) else None

    boards = item.get("boards")
    if not isinstance(boards, list):
        boards = []

    # boards entries usually contain fqbn/name when detected
    for b in boards:
        fqbn = (b.get("fqbn") or "").strip()
        name = (b.get("name") or "").strip()
        if port:
            candidates.append((port, fqbn, name))

# 1) Exact match or startswith match (handles *_dbg variants)
for port, fqbn, name in candidates:
    if fqbn and (fqbn == fqbn_target or fqbn.startswith(fqbn_target)):
        print(port)
        sys.exit(0)

# 2) If the tool reports a close variant (e.g. arduino_due_x_dbg), still accept if it contains the base token
base_token = fqbn_target.split(":")[-1]
for port, fqbn, name in candidates:
    if fqbn and base_token and base_token in fqbn:
        print(port)
        sys.exit(0)

# 3) Fallback: prefer usbmodem/usbserial over Bluetooth/console
pref = ["usbmodem", "usbserial", "ttyACM", "ttyUSB"]
for p in pref:
    for port, fqbn, name in candidates:
        if port and p in port:
            print(port)
            sys.exit(0)

print("")
PY
  )"
fi

# Fallback: some Arduino CLI versions omit detected FQBN info in JSON.
# In that case, parse the human table output and try to find the best match.
if [[ -z "$PORT" ]]; then
  BASE_TOKEN="${FQBN##*:}" # e.g. arduino_due_x

  # 1) Prefer an exact/substring FQBN match on the row.
  PORT="$(arduino-cli board list 2>/dev/null | awk -v fqbn="$FQBN" 'NR>1 { if ($0 ~ fqbn) { print $1; exit } }')"

  # 2) Accept closely-related variants (e.g. *_dbg).
  if [[ -z "$PORT" ]]; then
    PORT="$(arduino-cli board list 2>/dev/null | awk -v tok="$BASE_TOKEN" 'NR>1 { if ($0 ~ tok) { print $1; exit } }')"
  fi

  # 3) Last resort: pick the first likely USB serial port (avoid Bluetooth/console).
  if [[ -z "$PORT" ]]; then
    PORT="$(arduino-cli board list 2>/dev/null | awk 'NR>1 { if ($1 ~ /usbmodem|usbserial|ttyACM|ttyUSB/) { print $1; exit } }')"
  fi
fi

if [[ -z "$PORT" ]]; then
  ce_err "No suitable port detected for board: $FQBN"
  ce_err "Tip: run: arduino-cli board list"
  ce_err "Then use: PORT=/dev/cu.usbmodemXXXX ./run.sh upload"
  ce_die "Upload aborted (no port)."
fi

ce_info "Port:  $PORT"
ce_title "arduino-cli upload"
run_cmd_bg_tee "$LOG_FILE" "Uploading via Arduino CLI..." arduino-cli upload \
  -p "$PORT" \
  --fqbn "$FQBN" \
  --input-dir "$ARD_BUILD" \
  "$SKETCH"

ce_ok "upload complete"
ce_ok "Log: $LOG_FILE"