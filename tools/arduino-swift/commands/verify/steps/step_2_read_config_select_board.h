// step_2_read_config_select_board.h
//
// Step 2 (verify): load JSON config + boards, select the target board.
//
// Responsibilities
// ----------------
// - Loads:
//     - <project_root>/config.json into ctx->cfg_json
//     - <tool_root>/boards.json into ctx->boards_json
// - Resolves selected board from config.json (key: "board")
// - Parses board attributes from boards.json:
//     - fqbn
//     - core
//     - swift_target (default: armv7-none-none-eabi)
//     - cpu         (default: cortex-m3)
//
// Contract:
// - Returns 1 on success, 0 on failure.
//

#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int verify_step_2_read_config_select_board(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
