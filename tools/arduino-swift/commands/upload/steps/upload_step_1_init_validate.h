// upload_step_1_init_validate.h
//
// Upload step 1: validate host environment.
//
// Responsibilities:
// - Ensure required host tools are present in PATH:
//     - arduino-cli
//
// Returns:
// - 1 on success
// - 0 on failure
//
#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int upload_step_1_init_validate(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
