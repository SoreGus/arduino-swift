#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# monitor.sh
# ------------------------------------------------------------
# What this step does:
#  1) Loads shared UI helpers from print.sh (colors, titles)
#  2) Detects a serial port (prefers Arduino Due)
#  3) Opens arduino-cli serial monitor
#
# Env vars:
#   PORT=/dev/cu.usbmodemXXXX   (optional)
#   BAUD=115200                 (optional)
# ------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STEPS_DIR="$ROOT_DIR/steps"
BUILD_DIR="$ROOT_DIR/build"
LOG="$BUILD_DIR/monitor.log"

mkdir -p "$BUILD_DIR"
: > "$LOG"

# ---------- Load shared UI ----------
if [[ -f "$STEPS_DIR/print.sh" ]]; then
  # shellcheck source=/dev/null
  source "$STEPS_DIR/print.sh"
else
  # Fallback (no colors)
  ce_title() { echo "==> $*"; }
  ce_info()  { echo "[INFO] $*"; }
  ce_ok()    { echo "[OK] $*"; }
  ce_err()   { echo "[ERR] $*" >&2; }
  ce_die()   { ce_err "$*"; exit 1; }
fi

# ---------- Helpers ----------
need() {
  command -v "$1" >/dev/null 2>&1 || ce_die "Missing dependency: $1"
}

pick_port() {
  # Prefer Arduino Due programming port
  arduino-cli board list | awk '
    /Arduino Due/ && /Programming Port/ {print $1; exit}
    NR>1 {fallback=$1}
    END {if (fallback) print fallback}
  '
}

# ---------- Main ----------
ce_title "Serial Monitor"

need arduino-cli

PORT="${PORT:-}"
BAUD="${BAUD:-115200}"

if [[ -z "$PORT" ]]; then
  ce_info "Detecting serial ports via arduino-cli..."
  PORT="$(pick_port || true)"
fi

if [[ -z "$PORT" ]]; then
  ce_err "No serial port detected."
  echo
  ce_info "Available ports:"
  arduino-cli board list | tee -a "$LOG"
  echo
  ce_die "Use: PORT=/dev/cu.usbmodemXXXX ./run.sh monitor"
fi

ce_ok "Using port: $PORT"
ce_ok "Baud rate : $BAUD"
ce_info "Log file  : $LOG"
echo

# ---------- Run monitor ----------
ce_title "arduino-cli monitor (press Ctrl+C to exit)"

# IMPORTANT:
# - Do NOT pipe through tee here, or Ctrl+C gets broken
# - We still log the header; live output stays raw
{
  echo "PORT=$PORT"
  echo "BAUD=$BAUD"
  echo "---- monitor start ----"
} >> "$LOG"

arduino-cli monitor \
  -p "$PORT" \
  -c baudrate="$BAUD"