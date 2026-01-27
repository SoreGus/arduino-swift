// step_3_host_deps_and_arduino_core.h
//
// Step 3 (verify): verify host dependencies and ensure Arduino core is installed.
//
// Responsibilities
// ----------------
// - Verifies required host tools exist in PATH:
//     - arduino-cli
//     - python3
// - Runs `arduino-cli core update-index` (best-effort)
// - Ensures the selected board's Arduino core is installed (ctx->core)
//
// Contract:
// - Returns 1 on success, 0 on failure.
//

#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int verify_step_3_host_deps_and_arduino_core(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
