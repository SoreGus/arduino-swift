// step_1_init_validate.c
#include "step_1_init_validate.h"

#include "common/build_log.h"
#include "util.h"

#include <stdlib.h>
#include <stdio.h>

static void ensure_swiftly_in_path(void) {
    const char* home = getenv("HOME");
    if (!home || !home[0]) return;

    const char* old = getenv("PATH");
    if (!old) old = "";

    char newpath[2048];
    snprintf(newpath, sizeof(newpath), "%s/.swiftly/bin:%s", home, old);
    setenv("PATH", newpath, 1);
}

int cmd_build_step_1_init_validate(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!dir_exists(ctx->runtime_arduino)) {
        log_error("Missing runtime arduino dir: %s", ctx->runtime_arduino);
        return 0;
    }
    if (!dir_exists(ctx->runtime_swift)) {
        log_error("Missing runtime swift dir: %s", ctx->runtime_swift);
        return 0;
    }
    if (!file_exists(ctx->config_path)) {
        log_error("config.json not found at: %s", ctx->config_path);
        return 0;
    }

    if (run_cmd("command -v arduino-cli >/dev/null 2>&1") != 0) {
        log_error("Missing dependency: arduino-cli");
        return 0;
    }
    if (run_cmd("command -v python3 >/dev/null 2>&1") != 0) {
        log_error("Missing dependency: python3");
        return 0;
    }

    ensure_swiftly_in_path();
    return 1;
}
