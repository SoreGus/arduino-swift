#include "step_2_read_config_select_board.h"

#include "common/build_context.h"
#include "common/build_log.h"

int cmd_build_step_2_read_config_select_board(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!build_ctx_load_json(ctx)) {
        log_error("Failed to read config.json / boards.json");
        log_info("Expected:");
        log_info("  - %s", ctx->config_path);
        log_info("  - %s", ctx->boards_path);
        return 0;
    }

    if (!build_ctx_select_board_and_parse(ctx)) {
        log_error("Failed to resolve selected board / libs");
        return 0;
    }

    log_info("board      : %s", ctx->board);
    log_info("fqbn_base  : %s", ctx->fqbn_base);
    log_info("fqbn_final : %s", ctx->fqbn_final);

    if (ctx->board_opts_csv[0]) log_info("board_opts : %s", ctx->board_opts_csv);
    else                        log_info("board_opts : (none)");

    if (ctx->core[0]) log_info("core       : %s", ctx->core);
    if (ctx->api[0])  log_info("api        : %s", ctx->api);

    log_info("swift_tgt  : %s", ctx->swift_target);
    log_info("cpu        : %s", ctx->cpu);
    if (ctx->float_abi[0]) log_info("float_abi  : %s", ctx->float_abi);
    if (ctx->fpu[0])       log_info("fpu        : %s", ctx->fpu);

    return 1;
}