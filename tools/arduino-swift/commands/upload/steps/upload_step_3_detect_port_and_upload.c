// upload_step_3_detect_port_and_upload.c
//
// Upload step 3: validate build outputs, detect port, and upload.
//
// Responsibilities:
// - Ensure build outputs exist (build/arduino_build + build/sketch).
// - Select PORT:
//    - env PORT, else auto-detect via arduino-cli board list (match ctx->fqbn).
//    - reject Bluetooth/pseudo-ports.
// - Run:
//    arduino-cli upload -p <PORT> --fqbn <FQBN> --input-dir <arduino_build> <sketch>
//
// Notes:
// - Works for Arduino Due and Uno R4 Minima (and future boards) because it uses ctx->fqbn.
// - If auto-detection fails, user can set PORT explicitly.

#include "upload/steps/upload_step_3_detect_port_and_upload.h"

#include "common/build_context.h"
#include "common/build_log.h"
#include "common/port_detect.h"
#include "util.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Local helper: verify command exists in PATH (portable, no proc_helpers dependency)
static int ensure_cmd_exists(const char* cmd) {
    if (!cmd || !cmd[0]) return 0;

    char buf[512];
    snprintf(buf, sizeof(buf), "command -v \"%s\" >/dev/null 2>&1", cmd);
    return run_cmd(buf) == 0;
}

static int ensure_build_outputs_exist(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!dir_exists(ctx->ard_build_dir)) {
        log_error("Build output not found: %s", ctx->ard_build_dir);
        log_info("Run:");
        log_info("  arduino-swift build");
        return 0;
    }

    if (!dir_exists(ctx->sketch_dir)) {
        log_error("Sketch workspace not found: %s", ctx->sketch_dir);
        log_info("Run:");
        log_info("  arduino-swift build");
        return 0;
    }

    return 1;
}

static void print_board_list_hint(void) {
    log_info("Detected boards (arduino-cli board list):");
    run_cmd("arduino-cli board list || true");
}

int upload_step_3_detect_port_and_upload(BuildContext* ctx) {
    if (!ctx) {
        log_error("Internal error: BuildContext is NULL");
        return 0;
    }

    if (!ensure_build_outputs_exist(ctx)) return 0;

    // Extra safety (usually checked in step_1, but cheap)
    if (!ensure_cmd_exists("arduino-cli")) {
        log_error("Missing dependency: arduino-cli");
        log_info("Install it and try again.");
        return 0;
    }

    char port[256] = {0};

    const char* env_port = getenv("PORT");
    if (env_port && env_port[0]) {
        strncpy(port, env_port, sizeof(port) - 1);
        port[sizeof(port) - 1] = 0;
    } else {
        if (!detect_port_for_fqbn(ctx->fqbn, port, sizeof(port))) {
            log_error("No suitable serial port detected for this board.");
            print_board_list_hint();
            log_info("Tip: force a port explicitly, e.g.:");
            log_info("  PORT=/dev/cu.usbmodemXXXX arduino-swift upload");
            return 0;
        }
    }

    if (!port[0]) {
        log_error("No port selected.");
        print_board_list_hint();
        return 0;
    }

    if (port_is_bad(port)) {
        log_error("Detected an invalid port (Bluetooth/pseudo-port): %s", port);
        log_info("Set PORT explicitly to a USB serial device (usbmodem/usbserial/ttyACM/ttyUSB).");
        print_board_list_hint();
        return 0;
    }

    log_info("Uploading...");
    log_info("FQBN: %s", ctx->fqbn);
    log_info("PORT: %s", port);

    char cmd[2048];
    snprintf(cmd, sizeof(cmd),
        "arduino-cli upload -p \"%s\" --fqbn \"%s\" --input-dir \"%s\" \"%s\"",
        port, ctx->fqbn, ctx->ard_build_dir, ctx->sketch_dir
    );

    if (run_cmd(cmd) != 0) {
        log_error("arduino-cli upload failed");
        log_info("Tip: try pressing RESET once and re-run upload, or set PORT explicitly.");
        return 0;
    }

    log_info("Upload complete");
    return 1;
}
