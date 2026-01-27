// step_4_swift_toolchain_check.c
//
// Step 4 (verify): validate Embedded Swift toolchain supports the selected swift_target.

#include "verify/steps/step_4_swift_toolchain_check.h"

#include "common/build_log.h"

#include "util.h"

#include <string.h>
#include <stdio.h>

static void trim_newline(char* s) {
    if (!s) return;
    char* nl = strchr(s, '\n');
    if (nl) *nl = 0;
    nl = strchr(s, '\r');
    if (nl) *nl = 0;
}

static int ensure_cmd_exists(const char* cmd) {
    if (!cmd || !cmd[0]) return 0;

    char test[1024];
    snprintf(test, sizeof(test), "command -v \"%s\" >/dev/null 2>&1", cmd);
    return run_cmd(test) == 0;
}

// If ctx->swiftc is not an absolute path, resolve it via `command -v` (best-effort).
static void resolve_swiftc_to_absolute(BuildContext* ctx) {
    if (!ctx || !ctx->swiftc[0]) return;

    if (strchr(ctx->swiftc, '/')) return; // already looks like a path

    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "command -v \"%s\" 2>/dev/null", ctx->swiftc);

    char out[1024] = {0};
    if (run_cmd_capture(cmd, out, sizeof(out)) != 0) return;

    trim_newline(out);
    if (!out[0]) return;

    // overwrite with absolute path
    strncpy(ctx->swiftc, out, sizeof(ctx->swiftc) - 1);
    ctx->swiftc[sizeof(ctx->swiftc) - 1] = 0;
}

static int supports_embedded_swift(const char* swiftc_path, const char* swift_target) {
    if (!swiftc_path || !swiftc_path[0] || !swift_target || !swift_target[0]) return 0;

    char cmd[2400];
    // Extract runtimeResourcePath from swiftc -print-target-info JSON.
    snprintf(cmd, sizeof(cmd),
        "\"%s\" -print-target-info -target %s 2>/dev/null | "
        "awk -F'\"' '/runtimeResourcePath/ {print $4; exit}'",
        swiftc_path, swift_target
    );

    char out[1024] = {0};
    if (run_cmd_capture(cmd, out, sizeof(out)) != 0) return 0;
    trim_newline(out);
    if (!out[0]) return 0;

    char testcmd[1400];
    snprintf(testcmd, sizeof(testcmd), "[ -d \"%s/embedded\" ]", out);
    return run_cmd(testcmd) == 0;
}

int verify_step_4_swift_toolchain_check(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!ctx->swiftc[0]) {
        log_error("swiftc not configured.");
        log_error("Fix: run `arduino-swift verify` after installing an Embedded Swift toolchain,");
        log_error("or set: SWIFTC=/path/to/swiftc");
        return 0;
    }

    if (!ensure_cmd_exists(ctx->swiftc)) {
        log_error("Swift compiler not found: %s", ctx->swiftc);
        log_error("Fix options:");
        log_error("  1) Install swiftly + a suitable snapshot, or");
        log_error("  2) Set SWIFTC=/path/to/swiftc");
        return 0;
    }

    resolve_swiftc_to_absolute(ctx);

    if (!supports_embedded_swift(ctx->swiftc, ctx->swift_target)) {
        log_error("This swiftc does NOT support Embedded Swift for target '%s'.", ctx->swift_target);
        log_error("Fix options:");
        log_error("  1) Install a toolchain that includes Embedded Swift support, or");
        log_error("  2) Point SWIFTC to the correct toolchain.");
        return 0;
    }

    log_info("Embedded Swift toolchain OK: %s", ctx->swiftc);
    return 1;
}
