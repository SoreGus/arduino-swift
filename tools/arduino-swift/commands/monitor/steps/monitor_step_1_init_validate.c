// monitor_step_1_init_validate.c
//
// Step 1 (monitor): Validate host environment for `arduino-swift monitor`.
//
// Responsibilities:
// - Confirm required host dependency exists: arduino-cli
// - Print a short hint when missing
//
// This step is intentionally lightweight: monitor does not require python3 or swiftc.
//

#include "monitor/steps/monitor_step_1_init_validate.h"

#include "common/build_log.h"
#include "util.h"

#include <stdio.h>  // snprintf

static int ensure_cmd_exists(const char* cmd) {
    char buf[256];

    if (!cmd || !cmd[0]) {
        log_error("Internal error: empty command name");
        return 0;
    }

    snprintf(buf, sizeof(buf), "command -v \"%s\" >/dev/null 2>&1", cmd);
    if (run_cmd(buf) != 0) {
        log_error("Missing dependency: %s", cmd);
        log_error("Install it and re-run:");
        log_error("  arduino-swift monitor");
        return 0;
    }

    log_info("Found %s", cmd);
    return 1;
}

int monitor_step_1_init_validate(BuildContext* ctx) {
    (void)ctx;

    if (!ensure_cmd_exists("arduino-cli")) return 0;

    // Best-effort: show version (helps debugging PATH issues).
    run_cmd("arduino-cli version || true");
    return 1;
}
