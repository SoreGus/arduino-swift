// step_5_compile_and_arduino_cli.h
//
// Build step 5: compile_and_arduino_cli
//
// Compiles Swift into a single .o and runs arduino-cli compile (injecting the Swift object).
// Captures tool logs.
//
// Contract:
// - Returns 1 on success, 0 on failure.
//
#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int cmd_build_step_5_compile_and_arduino_cli(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
