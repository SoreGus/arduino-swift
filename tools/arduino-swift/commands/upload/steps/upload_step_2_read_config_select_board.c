#include "upload/steps/upload_step_2_read_config_select_board.h"

#include "common/build_context.h"
#include "common/build_log.h"

int upload_step_2_read_config_select_board(BuildContext* ctx) {
    if (!ctx) {
        log_error("Internal error: BuildContext is NULL");
        return 0;
    }

    if (!build_ctx_load_json(ctx)) {
        log_error("Failed to read config.json / boards.json");
        log_info("Expected:");
        log_info("  - %s", ctx->config_path);
        log_info("  - %s", ctx->boards_path);
        return 0;
    }

    if (!build_ctx_select_board_and_parse(ctx)) {
        log_error("Failed to resolve selected board from config.json");
        log_info("Tip: check your config.json contains a valid \"board\" key that exists in boards.json.");
        return 0;
    }

    if (!ctx->fqbn_final[0]) {
        log_error("Internal error: selected board did not populate FQBN.");
        return 0;
    }

    log_info("FQBN: %s", ctx->fqbn_final);
    if (ctx->board_opts_csv[0]) log_info("Board options: %s", ctx->board_opts_csv);

    return 1;
}