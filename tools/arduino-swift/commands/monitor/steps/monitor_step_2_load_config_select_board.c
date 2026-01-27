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

    log_info("board      : %s", ctx->board);
    log_info("fqbn_base  : %s", ctx->fqbn_base);
    log_info("fqbn_final : %s", ctx->fqbn_final);
    if (ctx->board_opts_csv[0]) log_info("board_opts : %s", ctx->board_opts_csv);

    return 1;
}