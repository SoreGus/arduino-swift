#!/usr/bin/env bash
set -euo pipefail

: '
run.sh
------
Project task runner.

Usage:
  ./run.sh verify   # verify dependencies, Arduino core, and Embedded Swift toolchain
  ./run.sh compile  # build Swift object + Arduino CLI compile
  ./run.sh upload   # upload to the board
  ./run.sh monitor  # serial monitor
  ./run.sh clean    # remove build artifacts
  ./run.sh all      # verify + compile + upload
'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEPS_DIR="$ROOT_DIR/steps"

PRINT_SH="$ROOT_DIR/print.sh"
ENV_SH="$ROOT_DIR/build/env.sh"

# Load shared UI helpers if available
if [[ -f "$PRINT_SH" ]]; then
  # shellcheck disable=SC1090
  source "$PRINT_SH"
else
  # Minimal fallback (keeps script usable even without print.sh)
  ce_title() { echo; echo "=================================================="; echo "$*"; echo "=================================================="; }
  ce_step() { echo; echo "=================================================="; echo "==> STEP: $*"; echo "=================================================="; }
  ce_info() { echo "INFO  $*"; }
  ce_ok()   { echo "OK    $*"; }
  ce_warn() { echo "WARN  $*" >&2; }
  ce_err()  { echo "ERR   $*" >&2; }
  ce_die()  { ce_err "$*"; exit 1; }
fi

usage() {
  ce_title "ArduinoSwift — Task Runner"
  echo "Usage:"
  echo "  ./run.sh verify"
  echo "  ./run.sh compile"
  echo "  ./run.sh upload"
  echo "  ./run.sh monitor"
  echo "  ./run.sh clean"
  echo "  ./run.sh all"
  exit 1
}

run_step() {
  local step="$1"
  local script="$STEPS_DIR/$step.sh"

  if [[ ! -f "$script" ]]; then
    ce_die "Step script not found: $script"
  fi
  if [[ ! -x "$script" ]]; then
    ce_die "Step script is not executable: $script (fix: chmod +x steps/*.sh run.sh)"
  fi

  # If verify generated an environment file (toolchain paths), load it for the next steps.
  if [[ -f "$ENV_SH" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_SH"
  fi

  ce_step "$step"
  bash "$script"
}

cmd="${1:-}"
[[ -n "$cmd" ]] || usage

case "$cmd" in
  verify)  run_step verify ;;
  compile) run_step compile ;;
  upload)  run_step upload ;;
  monitor) run_step monitor ;;
  clean)
    ce_step "clean"
    rm -rf "$ROOT_DIR/build"
    ce_ok "Build directory removed."
    ;;
  all)
    run_step verify
    run_step compile
    run_step upload
    ;;
  *)
    usage
    ;;
esac