// cmd_monitor.c
//
// ArduinoSwift serial monitor command (orchestrator).
//
// This file intentionally contains *no heavy logic*.
// All monitor work is split into a small number of steps under:
//
//   commands/monitor/steps/
//
// Steps:
//  1) Validate host environment (arduino-cli present)
//  2) Load config.json + boards.json and resolve the selected board (FQBN)
//  3) Pick PORT + BAUD and run `arduino-cli monitor`
//
// Port selection rules:
//  - If env PORT is set, it is used as-is (after safety validation).
//  - Otherwise auto-detect a port by matching the selected FQBN via `arduino-cli board list`.
//
// Baud rules:
//  - If env BAUD is set, it is used.
//  - Otherwise defaults to 115200.
//
// IMPORTANT:
// - Step function names are namespaced to avoid duplicate symbols at link time
//   (cmd_build/upload/monitor each have their own step_1/step_2/...).
//

#include "util.h"

#include "common/build_context.h"
#include "common/build_log.h"

#include "monitor/steps/monitor_step_1_init_validate.h"
#include "monitor/steps/monitor_step_2_load_config_select_board.h"
#include "monitor/steps/monitor_step_3_open_monitor.h"

#include <string.h> // memset
#include <stddef.h> // size_t

typedef int (*monitor_step_fn)(BuildContext* ctx);

typedef struct {
    const char* name;
    monitor_step_fn fn;
} MonitorStep;

static int run_step(BuildContext* ctx, const MonitorStep* s) {
    log_step_begin(s->name);

    const int ok = s->fn(ctx);
    if (ok) {
        log_step_ok();
        return 1;
    }

    log_step_fail("%s", s->name);
    return 0;
}

int cmd_monitor(int argc, char** argv) {
    (void)argc;
    (void)argv;

    BuildContext ctx;
    memset(&ctx, 0, sizeof(ctx));

    if (!build_ctx_init(&ctx)) {
        log_error("Failed to initialize context (ARDUINO_SWIFT_ROOT / tool root)");
        build_ctx_destroy(&ctx);
        return 1;
    }

    const MonitorStep steps[] = {
        { "1) Init + validate environment",       monitor_step_1_init_validate },
        { "2) Load config + select board",        monitor_step_2_load_config_select_board },
        { "3) Open serial monitor",               monitor_step_3_open_monitor },
    };

    log_info("ArduinoSwift monitor");
    log_info("Project: %s", ctx.project_root);
    log_info("Tool:    %s", ctx.tool_root);
    log_info("");

    int ok_all = 1;
    for (size_t i = 0; i < (sizeof(steps) / sizeof(steps[0])); i++) {
        if (!run_step(&ctx, &steps[i])) {
            ok_all = 0;
            break;
        }
        log_info("");
    }

    if (!ok_all) {
        log_error("Monitor failed.");
        log_info("Tip: try setting PORT explicitly, e.g.:");
        log_info("  PORT=/dev/cu.usbmodemXXXX BAUD=115200 arduino-swift monitor");
    }

    build_ctx_destroy(&ctx);
    return ok_all ? 0 : 1;
}
