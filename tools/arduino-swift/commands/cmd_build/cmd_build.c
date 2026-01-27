// cmd_build.c
//
// ArduinoSwift build command (orchestrator).
//
// This file intentionally contains *no heavy logic*.
// All build work is split into a small number of steps under:
//
//   commands/cmd_build/steps/
//
// The orchestrator is responsible for:
// - Creating and initializing BuildContext (paths, tool root, project root).
// - Performing a small, friendly preflight (the most common `verify` checks).
// - Running each step in order.
// - Printing clean, colored, start/ok/fail logs for each step.
// - Returning a non-zero exit code on failure.
//
// Steps (high-level, max ~5):
//  1) Init + validate environment (dependencies, PATH tweaks)
//  2) Read config.json + select board (boards.json) + parse libs
//  3) Prepare sketch workspace (clean/mkdir + copy runtime sketch template)
//  4) Stage sources and libs (Swift core/libs/main.swift + Arduino libs + force-compile TU)
//  5) Compile Swift + invoke arduino-cli (inject Swift .o)
//
// Notes:
// - Each step prints its own focused logs. The orchestrator only frames them.
// - Common helpers used by other commands live under commands/common/.
// - This orchestrator performs a lightweight preflight so failures are more friendly,
//   especially when the user forgot to run `arduino-swift verify`.
//
// Compatibility notes:
// - Must work for Arduino Due and Uno R4 Minima (and future boards) by deriving the
//   Arduino "core" identifier from FQBN (e.g. "arduino:sam" from "arduino:sam:due").
// - Avoid over-verbose logs; keep tool logs visible when needed.

#include "util.h"

#include "common/build_context.h"
#include "common/build_log.h"

#include "steps/step_1_init_validate.h"
#include "steps/step_2_read_config_select_board.h"
#include "steps/step_3_prepare_sketch_workspace.h"
#include "steps/step_4_stage_sources_and_libs.h"
#include "steps/step_5_compile_and_arduino_cli.h"

#include <string.h> // memset, strncpy, strchr
#include <stdio.h>  // snprintf

typedef int (*build_step_fn)(BuildContext* ctx);

typedef struct {
    const char* name;
    build_step_fn fn;
} BuildStep;

// -----------------------------
// Small local helpers
// -----------------------------

static int ensure_cmd_exists(const char* cmd) {
    if (!cmd || !cmd[0]) return 0;

    char test[512];
    snprintf(test, sizeof(test), "command -v \"%s\" >/dev/null 2>&1", cmd);
    if (run_cmd(test) != 0) return 0;
    return 1;
}

// Derive Arduino core from fqbn as "<vendor>:<platform>"
// Examples:
// - "arduino:sam:due" -> "arduino:sam"
// - "arduino:renesas_uno:uno_r4_minima" -> "arduino:renesas_uno"
static int fqbn_to_core(const char* fqbn, char* out, size_t cap) {
    if (!out || cap == 0) return 0;
    out[0] = 0;
    if (!fqbn || !fqbn[0]) return 0;

    const char* first = strchr(fqbn, ':');
    if (!first) return 0;
    const char* second = strchr(first + 1, ':');
    if (!second) return 0;

    size_t n = (size_t)(second - fqbn);
    if (n >= cap) n = cap - 1;

    memcpy(out, fqbn, n);
    out[n] = 0;
    return out[0] ? 1 : 0;
}

static int ensure_arduino_core_installed_from_fqbn(const char* fqbn) {
    char core[256];
    if (!fqbn_to_core(fqbn, core, sizeof(core))) {
        // If we can't derive it, don't hard-fail here (arduino-cli compile might still work
        // if the user already has everything installed).
        log_warn("Could not derive Arduino core from FQBN. Skipping core preflight.");
        return 1;
    }

    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
             "arduino-cli core list | awk '{print $1}' | grep -qx \"%s\"",
             core);

    if (run_cmd(cmd) == 0) {
        log_info("Core installed: %s", core);
        return 1;
    }

    log_error("Arduino core not installed: %s", core);
    log_error("Fix options:");
    log_error("  1) Run: arduino-swift verify   (recommended)");
    log_error("  2) Or install manually:");
    log_error("     arduino-cli core update-index");
    log_error("     arduino-cli core install \"%s\"", core);
    return 0;
}

// Heuristic check used by verify:
// swiftc -print-target-info -> runtimeResourcePath -> check "<path>/embedded" exists
static int ensure_embedded_swift_supported(const char* swiftc, const char* swift_target) {
    if (!swiftc || !swiftc[0] || !swift_target || !swift_target[0]) return 0;

    char cmd[1600];
    snprintf(cmd, sizeof(cmd),
        "\"%s\" -print-target-info -target %s 2>/dev/null | "
        "awk -F'\"' '/runtimeResourcePath/ {print $4; exit}'",
        swiftc, swift_target
    );

    char out[1024] = {0};
    if (run_cmd_capture(cmd, out, sizeof(out)) != 0) return 0;

    char* nl = strchr(out, '\n');
    if (nl) *nl = 0;
    nl = strchr(out, '\r');
    if (nl) *nl = 0;

    if (!out[0]) return 0;

    char testcmd[1400];
    snprintf(testcmd, sizeof(testcmd), "[ -d \"%s/embedded\" ]", out);
    return run_cmd(testcmd) == 0;
}

static int run_step(BuildContext* ctx, const BuildStep* s) {
    log_step_begin(s->name);

    const int ok = s->fn(ctx);
    if (ok) {
        log_step_ok();
        return 1;
    }

    log_step_fail("%s", s->name);
    return 0;
}

// Friendly preflight (subset of verify)
static int preflight_verify_like(BuildContext* ctx) {
    // Basic structure checks (fast + friendly)
    if (!file_exists(ctx->config_path)) {
        log_error("config.json not found at: %s", ctx->config_path);
        log_error("Tip: run this command from your project folder, or set ARDUINO_SWIFT_ROOT.");
        return 0;
    }
    if (!file_exists(ctx->boards_path)) {
        log_error("boards.json not found at tool root: %s", ctx->boards_path);
        return 0;
    }

    // Required host deps
    if (!ensure_cmd_exists("arduino-cli")) {
        log_error("Missing dependency: arduino-cli");
        log_error("Install it and re-run:");
        log_error("  arduino-swift verify");
        log_error("  arduino-swift build");
        return 0;
    }
    if (!ensure_cmd_exists("python3")) {
        log_error("Missing dependency: python3");
        log_error("Install it and re-run:");
        log_error("  arduino-swift build");
        return 0;
    }

    // Swift toolchain existence
    if (!ensure_cmd_exists(ctx->swiftc)) {
        log_error("Swift compiler not found: %s", ctx->swiftc);
        log_error("Fix options:");
        log_error("  1) Run: arduino-swift verify   (recommended)");
        log_error("     (it writes build/.swiftc_path for builds)");
        log_error("  2) Or set SWIFTC explicitly, e.g.:");
        log_error("     SWIFTC=/path/to/swiftc arduino-swift build");
        return 0;
    }

    return 1;
}

// -----------------------------
// cmd_build
// -----------------------------

int cmd_build(int argc, char** argv) {
    (void)argc;
    (void)argv;

    BuildContext ctx;
    memset(&ctx, 0, sizeof(ctx));

    if (!build_ctx_init(&ctx)) {
        log_error("Failed to initialize build context");
        build_ctx_destroy(&ctx);
        return 1;
    }

    log_info("ArduinoSwift build");
    log_info("Project: %s", ctx.project_root);
    log_info("Tool:    %s", ctx.tool_root);
    log_info("Build:   %s", ctx.build_dir);
    log_info("");

    // Friendly preflight (before running steps)
    if (!preflight_verify_like(&ctx)) {
        build_ctx_destroy(&ctx);
        return 1;
    }

    const BuildStep steps[] = {
        { "1) Init + validate environment",               cmd_build_step_1_init_validate },
        { "2) Read config + select board + parse libs",   cmd_build_step_2_read_config_select_board },
        { "3) Prepare sketch workspace",                  cmd_build_step_3_prepare_sketch_workspace },
        { "4) Stage sources + libs",                      cmd_build_step_4_stage_sources_and_libs },
        { "5) Compile + arduino-cli build",               cmd_build_step_5_compile_and_arduino_cli },
    };

    int ok_all = 1;

    for (size_t i = 0; i < (sizeof(steps) / sizeof(steps[0])); i++) {
        if (!run_step(&ctx, &steps[i])) {
            ok_all = 0;
            break;
        }

        // After step 2, ctx has fqbn, swift_target, cpu, etc.
        if (ok_all && i == 1) {
            if (!ensure_arduino_core_installed_from_fqbn(ctx.fqbn)) {
                ok_all = 0;
                break;
            }

            if (!ensure_embedded_swift_supported(ctx.swiftc, ctx.swift_target)) {
                log_error("This swiftc does NOT support Embedded Swift for target '%s'.", ctx.swift_target);
                log_error("Fix options:");
                log_error("  1) Run: arduino-swift verify");
                log_error("  2) Or install a suitable toolchain and set SWIFTC explicitly.");
                ok_all = 0;
                break;
            }
        }

        log_info(""); // spacer between steps
    }

    if (ok_all) {
        log_info("Build complete");
        log_info("Artifacts: %s", ctx.ard_build_dir);
    } else {
        log_error("Build failed");
        log_error("Tip: inspect the logs above and the sketch tree under: %s", ctx.sketch_dir);
    }

    build_ctx_destroy(&ctx);
    return ok_all ? 0 : 1;
}
