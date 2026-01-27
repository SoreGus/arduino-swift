// upload_step_1_init_validate.c
//
// Upload step 1: validate host environment.
//
// Responsibilities:
// - Confirm required host dependency exists: arduino-cli
//
// This step is intentionally lightweight.

#include "upload/steps/upload_step_1_init_validate.h"

#include "common/build_log.h"
#include "util.h"

#include <stdio.h>  // snprintf

static int ensure_cmd_exists(const char* cmd) {
    if (!cmd || !cmd[0]) return 0;

    char buf[512];
    snprintf(buf, sizeof(buf), "command -v \"%s\" >/dev/null 2>&1", cmd);

    if (run_cmd(buf) != 0) {
        log_error("Missing dependency: %s", cmd);
        return 0;
    }

    log_info("Found %s", cmd);
    return 1;
}

int upload_step_1_init_validate(BuildContext* ctx) {
    (void)ctx;

    // arduino-cli is required for upload
    if (!ensure_cmd_exists("arduino-cli")) {
        log_error("Install it and try again.");
        return 0;
    }

    return 1;
}
