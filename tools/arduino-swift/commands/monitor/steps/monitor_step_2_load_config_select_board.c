// monitor_step_2_load_config_select_board.c
//
// Step 2 (monitor): Load config.json + boards.json and resolve the selected board.
//
// Responsibilities:
// - Load JSON into ctx->cfg_json / ctx->boards_json
// - Resolve board (config.json "board") into ctx->fqbn (and related fields)
//
// Notes:
// - Boards are resolved from tool-internal boards.json (tool root), not the project directory.
//

#include "monitor/steps/monitor_step_2_load_config_select_board.h"

#include "common/build_context.h"
#include "common/build_log.h"

int monitor_step_2_load_config_select_board(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!build_ctx_load_json(ctx)) {
        log_error("Failed to read config.json / boards.json");
        log_info("Expected:");
        log_info("  - %s", ctx->config_path);
        log_info("  - %s", ctx->boards_path);
        return 0;
    }

    if (!build_ctx_select_board_and_parse(ctx)) {
        log_error("Failed to resolve the selected board from boards.json");
        log_info("Tip: check your config.json contains a valid \"board\" key.");
        return 0;
    }

    if (ctx->board[0]) {
        log_info("board = %s", ctx->board);
    }
    log_info("fqbn  = %s", ctx->fqbn);

    return 1;
}
