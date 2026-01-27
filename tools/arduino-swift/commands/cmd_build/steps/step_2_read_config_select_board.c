// step_2_read_config_select_board.c
#include "step_2_read_config_select_board.h"

#include "common/build_log.h"

int cmd_build_step_2_read_config_select_board(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!build_ctx_load_json(ctx)) return 0;
    if (!build_ctx_select_board_and_parse(ctx)) return 0;

    log_info("Board: %s", ctx->board);
    log_info("FQBN : %s", ctx->fqbn);
    log_info("Swift: target=%s cpu=%s swiftc=%s", ctx->swift_target, ctx->cpu, ctx->swiftc);

    if (ctx->swift_lib_count > 0) log_info("Swift libs enabled: %d", ctx->swift_lib_count);
    else                         log_info("Swift libs enabled: 0 (core only)");

    if (ctx->arduino_lib_count > 0 && ctx->user_arduino_lib_dir[0]) {
        log_info("User Arduino libs enabled: %d (dir=%s)", ctx->arduino_lib_count, ctx->user_arduino_lib_dir);
    }

    return 1;
}
