// monitor_step_3_open_monitor.c
//
// Step 3 (monitor): Choose PORT + BAUD and open `arduino-cli monitor`.
//
// Responsibilities:
// - PORT selection:
//    - Use env PORT if present (after safety validation)
//    - Else auto-detect a suitable port for ctx->fqbn via `arduino-cli board list`
// - BAUD selection:
//    - Use env BAUD if present
//    - Else default to 115200
// - Execute:
//    arduino-cli monitor -p <PORT> -c baudrate=<BAUD>
//
// Notes:
// - If auto-detection fails, print `arduino-cli board list` to aid debugging.
// - We execute arduino-cli directly (no piping) so Ctrl+C works.
//

#include "monitor/steps/monitor_step_3_open_monitor.h"

#include "common/build_log.h"
#include "common/port_detect.h"
#include "util.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void print_board_list_hint(void) {
    log_info("Detected boards (arduino-cli board list):");
    run_cmd("arduino-cli board list || true");
}

int monitor_step_3_open_monitor(BuildContext* ctx) {
    if (!ctx) return 0;

    const char* port_env = getenv("PORT");
    const char* baud_env = getenv("BAUD");
    const char* baud = (baud_env && baud_env[0]) ? baud_env : "115200";

    char port[256] = {0};

    if (port_env && port_env[0]) {
        strncpy(port, port_env, sizeof(port) - 1);
        port[sizeof(port) - 1] = 0;
    } else {
        if (!detect_port_for_fqbn(ctx->fqbn, port, sizeof(port))) {
            log_error("No suitable serial port detected for FQBN: %s", ctx->fqbn);
            print_board_list_hint();
            log_info("Tip: set PORT explicitly, e.g.:");
            log_info("  PORT=/dev/cu.usbmodemXXXX BAUD=%s arduino-swift monitor", baud);
            return 0;
        }
    }

    if (!port[0]) {
        log_error("No serial port selected.");
        print_board_list_hint();
        return 0;
    }

    if (port_is_bad(port)) {
        log_error("Detected an invalid port (Bluetooth / pseudo-port): %s", port);
        log_info("Set PORT explicitly to a USB serial device (usbmodem/usbserial/ttyACM/ttyUSB).");
        print_board_list_hint();
        return 0;
    }

    log_info("Monitor: PORT=%s BAUD=%s", port, baud);

    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
             "arduino-cli monitor -p \"%s\" -c baudrate=\"%s\"",
             port, baud);

    if (run_cmd(cmd) != 0) {
        log_error("arduino-cli monitor failed");
        return 0;
    }

    return 1;
}
