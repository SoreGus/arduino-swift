// step_3_host_deps_and_arduino_core.c
//
// Step 3 (verify): verify host dependencies and ensure Arduino core is installed.

#include "verify/steps/step_3_host_deps_and_arduino_core.h"

#include "common/build_log.h"

#include "util.h"

#include <stdio.h>
#include <string.h>

static int ensure_cmd_exists(const char* cmd) {
    if (!cmd || !cmd[0]) return 0;

    char buf[512];
    snprintf(buf, sizeof(buf), "command -v \"%s\" >/dev/null 2>&1", cmd);
    if (run_cmd(buf) != 0) {
        log_error("Missing dependency: %s", cmd);
        return 0;
    }
    log_info("Found: %s", cmd);
    return 1;
}

static int is_core_installed(const char* core) {
    if (!core || !core[0]) return 1;

    char cmd[1200];
    // "arduino-cli core list" prints a table. Column 1 is the core ID.
    snprintf(cmd, sizeof(cmd),
             "arduino-cli core list 2>/dev/null | awk '{print $1}' | grep -qx \"%s\"",
             core);
    return run_cmd(cmd) == 0;
}

int verify_step_3_host_deps_and_arduino_core(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!ensure_cmd_exists("arduino-cli")) return 0;
    if (!ensure_cmd_exists("python3")) return 0;

    // Best-effort index update.
    if (run_cmd("arduino-cli core update-index") != 0) {
        log_warn("arduino-cli core update-index failed (continuing). You may be offline.");
    } else {
        log_info("Arduino core index updated.");
    }

    // Ensure core installed (if boards.json provides it).
    if (!ctx->core[0]) {
        log_warn("No 'core' for board '%s' (boards.json). Skipping core install check.", ctx->board);
        return 1;
    }

    if (is_core_installed(ctx->core)) {
        log_info("Core installed: %s", ctx->core);
        return 1;
    }

    log_error("Arduino core not installed: %s", ctx->core);
    log_error("Fix:");
    log_error("  arduino-cli core install \"%s\"", ctx->core);
    log_error("Then re-run:");
    log_error("  arduino-swift verify");

    return 0;
}
