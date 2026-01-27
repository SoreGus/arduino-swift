// build_log.h
//
// Lightweight, consistent logging utilities for ArduinoSwift CLI commands.
//
// Goals:
// - Provide colored, structured logs: step begin/end, ok/fail, info/warn.
// - Avoid noisy output by default, but preserve tool logs in files.
// - Support "verbose" mode for streaming tool output to the console.
//
// Environment:
// - ARDUINO_SWIFT_VERBOSE=1    Stream tool output to stdout as it runs.
//
// Notes:
// - This logger intentionally does NOT depend on any external library.
// - It is meant to be used by all commands (cmd_build, cmd_upload, etc.)
//
// Typical usage:
//   log_init();
//   log_step_begin("build:init_validate");
//   ...
//   log_step_ok();
//
// For failures:
//   log_step_fail("Missing dependency: arduino-cli");
//
#pragma once

#include <stdio.h>
#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif

void log_init(void);
int  log_is_verbose(void);

void log_info(const char* fmt, ...);
void log_warn(const char* fmt, ...);
void log_error(const char* fmt, ...);

void log_cmd(const char* fmt, ...);

void log_step_begin(const char* step_name);
void log_step_ok(void);
void log_step_fail(const char* fmt, ...);

void log_sep(void);

// vprintf-style helper (exposed for wrappers if needed).
void log_vprintf(FILE* out, const char* prefix, const char* color, const char* fmt, va_list ap);

#ifdef __cplusplus
} // extern "C"
#endif
