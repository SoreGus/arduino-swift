// step_1_init_validate.h
//
// Build step 1: init_validate
//
// Validates runtime directories and required external dependencies.
// Ensures PATH includes swiftly (best-effort).
//
// Contract:
// - Returns 1 on success, 0 on failure.
//
#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int cmd_build_step_1_init_validate(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
