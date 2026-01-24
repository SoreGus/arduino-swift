#!/usr/bin/env bash
set -euo pipefail

: '
print.sh
--------
Shared CLI UI helpers for ArduinoSwift.

What this file provides:
  - Colors + styles (auto-disabled when not in a TTY)
  - Pretty headers/sections
  - Log helpers: info/ok/warn/err/die
  - Spinners (loading) that work on macOS (bash 3.2) + Linux
  - Command runners:
      * run_cmd     -> streams output live (recommended to see everything)
      * run_cmd_bg  -> shows a spinner while capturing output, then prints it (luxury loading)
'

# --------------------------------------------
# Detect terminal capabilities
# --------------------------------------------
_ce_is_tty() { [[ -t 1 ]]; }

_ce_has_color() {
  if ! _ce_is_tty; then return 1; fi
  if [[ "${NO_COLOR:-}" != "" ]]; then return 1; fi
  # TERM=dumb -> no color
  if [[ "${TERM:-dumb}" == "dumb" ]]; then return 1; fi
  return 0
}

# --------------------------------------------
# Styles (ANSI)
# --------------------------------------------
if _ce_has_color; then
  CE_RST=$'\033[0m'
  CE_BLD=$'\033[1m'
  CE_DIM=$'\033[2m'

  CE_RED=$'\033[31m'
  CE_GRN=$'\033[32m'
  CE_YEL=$'\033[33m'
  CE_BLU=$'\033[34m'
  CE_MAG=$'\033[35m'
  CE_CYN=$'\033[36m'
  CE_GRY=$'\033[90m'
else
  CE_RST=""; CE_BLD=""; CE_DIM=""
  CE_RED=""; CE_GRN=""; CE_YEL=""; CE_BLU=""; CE_MAG=""; CE_CYN=""; CE_GRY=""
fi

# --------------------------------------------
# Printing helpers
# --------------------------------------------
_ce_ts() {
  # Keep it simple and portable
  date "+%H:%M:%S"
}

ce_hr() {
  local w="${1:-48}"
  # shellcheck disable=SC2034
  local i
  printf "%s\n" "------------------------------------------------"
}

ce_title() {
  local msg="$*"
  echo
  echo "${CE_BLD}${CE_CYN}==================================================${CE_RST}"
  echo "${CE_BLD}${CE_CYN}$msg${CE_RST}"
  echo "${CE_BLD}${CE_CYN}==================================================${CE_RST}"
}

ce_step() {
  local name="$*"
  echo
  echo "${CE_BLD}${CE_CYN}==============================${CE_RST}"
  echo "${CE_BLD}${CE_CYN}==> STEP: ${name}${CE_RST}"
  echo "${CE_BLD}${CE_CYN}==============================${CE_RST}"
}

ce_info() { echo "${CE_BLD}${CE_CYN}INFO${CE_RST}  $*"; }
ce_ok()   { echo "${CE_BLD}${CE_GRN}OK${CE_RST}    $*"; }
ce_warn() { echo "${CE_BLD}${CE_YEL}WARN${CE_RST}  $*"; }
ce_err()  { echo "${CE_BLD}${CE_RED}ERR${CE_RST}   $*" >&2; }

ce_die() {
  ce_err "$*"
  exit 1
}

# --------------------------------------------
# Prompt helpers (bash 3.2 compatible)
# --------------------------------------------
ce_prompt_yn() {
  # Usage: ce_prompt_yn "Question?" "y"  (default y/n)
  local q="${1:-Are you sure?}"
  local def="${2:-n}"
  local ans=""

  if [[ "$def" == "y" ]]; then
    printf "%s [Y/n]: " "$q"
  else
    printf "%s [y/N]: " "$q"
  fi

  # Read from tty if possible (so piping doesn't break prompts)
  if [[ -r /dev/tty ]]; then
    read -r ans </dev/tty || true
  else
    read -r ans || true
  fi

  # Normalize manually (no ${var,,} because macOS bash 3.2)
  case "$ans" in
    "" )
      [[ "$def" == "y" ]] && return 0 || return 1
      ;;
    Y|y|YES|Yes|yes ) return 0 ;;
    * ) return 1 ;;
  esac
}

# --------------------------------------------
# Spinner (loading) — works on bash 3.2
# --------------------------------------------
CE_SPINNER_PID=""
CE_SPINNER_MSG=""

_ce_spinner_loop() {
  # Runs in background
  local frames='|/-\'
  local i=0
  while :; do
    i=$(( (i + 1) % 4 ))
    # print \r + spinner + message (stay on same line)
    printf "\r%s%s%s %s" "${CE_DIM}${CE_CYN}" "${frames:$i:1}" "${CE_RST}" "$CE_SPINNER_MSG"
    sleep 0.08
  done
}

ce_spinner_start() {
  # Usage: ce_spinner_start "Doing something..."
  CE_SPINNER_MSG="$*"

  # Only spinner on TTY
  if ! _ce_is_tty; then
    return 0
  fi

  # Avoid double-start
  if [[ "${CE_SPINNER_PID:-}" != "" ]]; then
    return 0
  fi

  _ce_spinner_loop &
  CE_SPINNER_PID="$!"
}

ce_spinner_stop() {
  # Usage: ce_spinner_stop "OK message" (optional)
  local final="${1:-}"

  if [[ "${CE_SPINNER_PID:-}" != "" ]]; then
    kill "$CE_SPINNER_PID" >/dev/null 2>&1 || true
    wait "$CE_SPINNER_PID" >/dev/null 2>&1 || true
    CE_SPINNER_PID=""
  fi

  if _ce_is_tty; then
    # Clear line
    printf "\r\033[2K"
  fi

  if [[ "$final" != "" ]]; then
    ce_ok "$final"
  fi
}

# Ensure spinner dies on exit
ce_spinner_trap_enable() {
  trap 'ce_spinner_stop >/dev/null 2>&1 || true' EXIT INT TERM
}

# --------------------------------------------
# Command runners
# --------------------------------------------

run_cmd() {
  : '
  run_cmd
  -------
  Streams stdout/stderr live (so you see everything).
  Returns the real exit code.

  Usage:
    run_cmd arduino-cli board list
  '
  ce_info "Running: $*"
  set +e
  "$@" 2>&1
  local rc=$?
  set -e
  return "$rc"
}

run_cmd_tee() {
  : '
  run_cmd_tee
  -----------
  Streams output live AND tees to a log file.

  Usage:
    run_cmd_tee "$LOG" arduino-cli compile ...
  '
  local log_file="$1"
  shift
  ce_info "Running: $*"
  set +e
  # tee keeps live output visible
  "$@" 2>&1 | tee -a "$log_file"
  local rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

run_cmd_bg() {
  : '
  run_cmd_bg
  ----------
  Luxury mode: shows a spinner while the command runs.
  Captures output to a temp file, then prints it all at the end.
  Good for long waits where you still want FULL output, but not interleaved with spinner.

  Usage:
    run_cmd_bg "Compiling..." arduino-cli compile ...
  '
  local msg="$1"
  shift

  local tmp
  tmp="$(mktemp -t arduinoswift_cmd.XXXXXX)"
  ce_spinner_trap_enable
  ce_spinner_start "$msg"

  set +e
  "$@" >"$tmp" 2>&1
  local rc=$?
  set -e

  ce_spinner_stop
  cat "$tmp"
  rm -f "$tmp"

  return "$rc"
}

run_cmd_bg_tee() {
  : '
  run_cmd_bg_tee
  --------------
  Same as run_cmd_bg, but also appends output to a log file.

  Usage:
    run_cmd_bg_tee "$LOG" "Installing core..." arduino-cli core install ...
  '
  local log_file="$1"
  local msg="$2"
  shift 2

  local tmp
  tmp="$(mktemp -t arduinoswift_cmd.XXXXXX)"
  ce_spinner_trap_enable
  ce_spinner_start "$msg"

  set +e
  "$@" >"$tmp" 2>&1
  local rc=$?
  set -e

  ce_spinner_stop
  cat "$tmp" | tee -a "$log_file"
  rm -f "$tmp"

  return "$rc"
}