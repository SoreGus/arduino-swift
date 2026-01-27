// proc_helpers.h
//
// Process execution helpers for ArduinoSwift CLI commands.
//
// Goals:
// - Run external tools (swiftc, arduino-cli, etc.)
// - Capture logs to files for later diagnostics
// - Optionally stream output live when verbose mode is enabled
//
// Dependencies:
// - Uses popen/pclose (POSIX).
//
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int proc_run_tee(const char* cmd, const char* log_path, int verbose);
int proc_tail_file(const char* path, int max_lines);
int proc_mkdir_parent_for_file(const char* path);

#ifdef __cplusplus
} // extern "C"
#endif
