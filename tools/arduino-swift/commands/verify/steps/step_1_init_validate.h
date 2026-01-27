// step_1_init_validate.h
//
// Step 1 (verify): init + validate project/tool layout.
//
// Responsibilities
// ----------------
// - Validate required files exist:
//     - <project_root>/config.json
//     - <tool_root>/boards.json
// - Ensure build directories exist:
//     - <project_root>/build
//     - <project_root>/build/logs
// - Ensure $HOME/.swiftly/bin is present in PATH (best-effort) so swiftc
//   discovery works for typical installations.
//
// Contract:
// - Returns 1 on success, 0 on failure.
//

#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int verify_step_1_init_validate(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
