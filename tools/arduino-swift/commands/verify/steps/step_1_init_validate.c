// step_1_init_validate.c
//
// Step 1 (verify): init + validate project/tool layout.
//
// This step is intentionally lightweight:
// - Does NOT call external tools (arduino-cli, swiftc).
// - Validates required files/dirs.
// - Prepares <build>/ and <build>/logs/.
// - Tweaks PATH to include ~/.swiftly/bin (best-effort).
//
// Return value:
// - 1 on success
// - 0 on failure

#include "verify/steps/step_1_init_validate.h"

#include "common/build_log.h"
#include "common/fs_helpers.h"

#include "util.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static void prepend_swiftly_bin_to_path(void) {
    const char* home = getenv("HOME");
    if (!home || !home[0]) return;

    const char* old_path = getenv("PATH");
    if (!old_path) old_path = "";

    char new_path[2048];
    // NOTE: best-effort. If truncated, still safe (PATH just may not include swiftly).
    snprintf(new_path, sizeof(new_path), "%s/.swiftly/bin:%s", home, old_path);
    setenv("PATH", new_path, 1);
}

int verify_step_1_init_validate(BuildContext* ctx) {
    if (!ctx) {
        log_error("Internal error: BuildContext is NULL");
        return 0;
    }

    // Required inputs
    if (!file_exists(ctx->config_path)) {
        log_error("Missing required file: %s", ctx->config_path);
        log_error("Tip: run from your project folder or set ARDUINO_SWIFT_ROOT.");
        return 0;
    }

    // boards.json is tool-internal and must exist near the binary/tool root.
    if (!file_exists(ctx->boards_path)) {
        log_error("Missing required file: %s", ctx->boards_path);
        log_error("boards.json must exist at the tool root: %s", ctx->tool_root);
        return 0;
    }

    // Build directories
    if (!fs_mkdir_p(ctx->build_dir)) {
        log_error("Failed to create build dir: %s", ctx->build_dir);
        return 0;
    }

    if (!fs_mkdir_p(ctx->logs_dir)) {
        log_error("Failed to create logs dir: %s", ctx->logs_dir);
        return 0;
    }

    prepend_swiftly_bin_to_path();

    log_info("Project root : %s", ctx->project_root);
    log_info("Tool root    : %s", ctx->tool_root);
    log_info("Build dir    : %s", ctx->build_dir);
    log_info("Logs dir     : %s", ctx->logs_dir);

    return 1;
}
