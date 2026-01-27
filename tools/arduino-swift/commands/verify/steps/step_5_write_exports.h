// step_5_write_exports.h
//
// Step 5 (verify): write build-time exports used by downstream commands.
//
// Responsibilities
// ----------------
// Writes these files under <project_root>/build:
// - .swiftc_path : absolute path to swiftc (single line)
// - env.sh       : export SWIFTC, board/fqbn/core, SWIFT_TARGET, SWIFT_CPU
//
// Contract:
// - Returns 1 on success, 0 on failure.
//

#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int verify_step_5_write_exports(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
