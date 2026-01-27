// cmd_verify.c
//
// Environment + toolchain verification for ArduinoSwift.
//
// High-level responsibilities:
// - Run a small set of focused steps under commands/verify/steps/.
// - Keep orchestration clean: frame steps, print friendly logs, return non-zero on failure.
//
// Steps:
//  1) Init + validate project/tool layout (files/dirs, create build/logs, PATH tweaks)
//  2) Read config.json + select board (boards.json) + fill ctx fields (fqbn, swift_target, cpu, etc)
//  3) Verify host deps + ensure Arduino core is installed
//  4) Verify Embedded Swift toolchain supports the selected swift_target
//  5) Write exports (build/.swiftc_path, build/env.sh)
//
// Notes:
// - This file intentionally avoids heavy logic. Each step owns its checks.
// - Uses the common logging API from commands/common/build_log.h.

#include "common/build_context.h"
#include "common/build_log.h"

#include "verify/steps/step_1_init_validate.h"
#include "verify/steps/step_2_read_config_select_board.h"
#include "verify/steps/step_3_host_deps_and_arduino_core.h"
#include "verify/steps/step_4_swift_toolchain_check.h"
#include "verify/steps/step_5_write_exports.h"

#include <string.h> // memset
#include <stddef.h> // size_t

typedef int (*verify_step_fn)(BuildContext* ctx);

typedef struct {
    const char* name;
    verify_step_fn fn;
} VerifyStep;

static int run_step(BuildContext* ctx, const VerifyStep* s) {
    log_step_begin(s->name);

    const int ok = s->fn(ctx) ? 1 : 0;
    if (ok) {
        log_step_ok(); // build_log.h: log_step_ok(void)
        return 1;
    }

    log_step_fail("%s", s->name); // build_log.h: log_step_fail(const char* fmt, ...)
    return 0;
}

int cmd_verify(int argc, char** argv) {
    (void)argc;
    (void)argv;

    BuildContext ctx;
    memset(&ctx, 0, sizeof(ctx));

    if (!build_ctx_init(&ctx)) {
        log_error("Failed to initialize build context");
        build_ctx_destroy(&ctx);
        return 1;
    }

    log_info("ArduinoSwift verify");
    log_info("Project: %s", ctx.project_root);
    log_info("Tool:    %s", ctx.tool_root);
    log_info("Build:   %s", ctx.build_dir);
    log_info("");

    const VerifyStep steps[] = {
        { "1) Init + validate layout",        verify_step_1_init_validate },
        { "2) Load config + select board",    verify_step_2_read_config_select_board },
        { "3) Host deps + Arduino core",      verify_step_3_host_deps_and_arduino_core },
        { "4) Swift toolchain check",         verify_step_4_swift_toolchain_check },
        { "5) Write exports",                 verify_step_5_write_exports },
    };

    int ok_all = 1;
    for (size_t i = 0; i < (sizeof(steps) / sizeof(steps[0])); i++) {
        if (!run_step(&ctx, &steps[i])) {
            ok_all = 0;
            break;
        }
        log_info("");
    }

    if (ok_all) {
        log_info("verify complete.");
    } else {
        log_error("verify failed.");
        log_error("Tip: read the logs above and fix the first failing step.");
    }

    build_ctx_destroy(&ctx);
    return ok_all ? 0 : 1;
}
