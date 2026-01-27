// step_2_read_config_select_board.h
//
// Build step 2: read_config_select_board
//
// Loads config.json and boards.json, parses configuration,
// and selects board/toolchain fields.
//
// Contract:
// - Returns 1 on success, 0 on failure.
//
#pragma once
#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int cmd_build_step_2_read_config_select_board(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif