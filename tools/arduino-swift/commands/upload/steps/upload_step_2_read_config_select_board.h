// upload_step_2_read_config_select_board.h
//
// Upload step 2: load config.json and resolve board info.
//
// Responsibilities:
// - Read config.json and tool-owned boards.json.
// - Resolve selected board:
//     - fqbn
//     - core (informational for upload)
// - Populate BuildContext fields for downstream steps.
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

int upload_step_2_read_config_select_board(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
