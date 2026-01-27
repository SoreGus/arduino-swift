// cmd_upload.c
//
// ArduinoSwift upload command (orchestrator).
//
// This file intentionally contains *no heavy logic*.
// All upload work is split into a small number of steps under:
//
//   commands/upload/steps/
//
// The orchestrator is responsible for:
// - Creating and initializing BuildContext (paths, tool root, project root).
// - Running each step in order.
// - Printing clean, colored, start/ok/fail logs for each step.
// - Returning a non-zero exit code on failure.
//
// Steps (high-level):
//  1) Init + validate environment (host dependencies)
//  2) Read config.json + select board (boards.json) + resolve fqbn
//  3) Detect port + upload via arduino-cli
//
// Notes:
// - Upload works for any supported board, including Arduino Due and Uno R4 Minima,
//   as long as the Arduino core is installed and the board is in a normal upload mode.
// - If auto-detection fails, users can force a port with:
//     PORT=/dev/cu.usbmodemXXXX arduino-swift upload
//
// Common helpers shared with other commands live under commands/common/.

#include "util.h"

#include "common/build_context.h"
#include "common/build_log.h"

#include "upload/steps/upload_step_1_init_validate.h"
#include "upload/steps/upload_step_2_read_config_select_board.h"
#include "upload/steps/upload_step_3_detect_port_and_upload.h"

#include <string.h> // memset
#include <stddef.h> // size_t

typedef int (*upload_step_fn)(BuildContext* ctx);

typedef struct {
    const char* name;
    upload_step_fn fn;
} UploadStep;

static int run_step(BuildContext* ctx, const UploadStep* s) {
    log_step_begin(s->name);

    const int ok = s->fn(ctx) ? 1 : 0;
    if (ok) {
        // build_log.h declares: void log_step_ok(void);
        log_step_ok();
        return 1;
    }

    // build_log.h expects printf-style for fail
    log_step_fail("%s", s->name);
    return 0;
}

int cmd_upload(int argc, char** argv) {
    (void)argc;
    (void)argv;

    BuildContext ctx;
    memset(&ctx, 0, sizeof(ctx));

    if (!build_ctx_init(&ctx)) {
        log_error("Failed to initialize build context");
        build_ctx_destroy(&ctx);
        return 1;
    }

    const UploadStep steps[] = {
        { "1) Init + validate environment",  upload_step_1_init_validate },
        { "2) Read config + select board",   upload_step_2_read_config_select_board },
        { "3) Detect port + upload",         upload_step_3_detect_port_and_upload },
    };

    int ok_all = 1;

    log_info("ArduinoSwift upload");
    log_info("Project: %s", ctx.project_root);
    log_info("Tool:    %s", ctx.tool_root);
    log_info("Build:   %s", ctx.build_dir);
    log_info("");

    for (size_t i = 0; i < (sizeof(steps) / sizeof(steps[0])); i++) {
        if (!run_step(&ctx, &steps[i])) {
            ok_all = 0;
            break;
        }
        log_info("");
    }

    if (ok_all) {
        log_info("Upload complete");
    } else {
        log_error("Upload failed");
        log_error("Tip: if port detection fails, set PORT explicitly, e.g.:");
        log_error("     PORT=/dev/cu.usbmodemXXXX arduino-swift upload");
    }

    build_ctx_destroy(&ctx);
    return ok_all ? 0 : 1;
}
