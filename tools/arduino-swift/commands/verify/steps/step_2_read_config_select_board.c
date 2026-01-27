// step_2_read_config_select_board.c
//
// Step 2 (verify): load JSON config + boards, select the target board.
//
// This step determines the *intended* build target from config.json and
// tool-internal boards.json. It does not validate toolchains or arduino cores.

#include "verify/steps/step_2_read_config_select_board.h"

#include "common/build_context.h"
#include "common/build_log.h"

int verify_step_2_read_config_select_board(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!build_ctx_load_json(ctx)) {
        // build_ctx_load_json should have logged details.
        return 0;
    }

    if (!build_ctx_select_board_and_parse(ctx)) {
        // build_ctx_select_board_and_parse should have logged details.
        return 0;
    }

    log_info("board        : %s", ctx->board);
    log_info("fqbn         : %s", ctx->fqbn);

    if (ctx->core[0]) log_info("core         : %s", ctx->core);
    else              log_warn("core         : (missing)");

    log_info("swift_target  : %s", ctx->swift_target);
    log_info("cpu          : %s", ctx->cpu);

    return 1;
}
