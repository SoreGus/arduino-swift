// step_5_compile_and_arduino_cli.c
#include "step_5_compile_and_arduino_cli.h"

#include "common/build_log.h"
#include "common/proc_helpers.h"
#include "util.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------

static int is_renesas_uno_fqbn(const BuildContext* ctx) {
    if (!ctx) return 0;
    // Example: "arduino:renesas_uno:minima"
    return (ctx->fqbn_final[0] && strstr(ctx->fqbn_final, "renesas_uno") != NULL);
}

static int is_mbed_giga_fqbn(const BuildContext* ctx) {
    if (!ctx) return 0;
    // Example: "arduino:mbed_giga:giga"
    return (ctx->fqbn_final[0] && strstr(ctx->fqbn_final, "mbed_giga") != NULL);
}

static int is_cpu_cortex_m4(const BuildContext* ctx) {
    if (!ctx) return 0;
    return (ctx->cpu[0] && strstr(ctx->cpu, "cortex-m4") != NULL);
}

static int str_contains_kv(const char* opts, const char* kv) {
    if (!opts || !kv) return 0;
    return strstr(opts, kv) != NULL;
}

/*
  Swift embedded stdlib availability:
    - Toolchain usually has: armv7em-none-none-eabi
    - Often does NOT have:   armv7em-none-none-eabihf
*/
static const char* swift_target_for_swiftc(const BuildContext* ctx) {
    if (!ctx) return "armv7-none-none-eabi";

    // If boards/config ever injects eabihf by mistake, fix only for swiftc:
    if (ctx->swift_target[0] &&
        strstr(ctx->swift_target, "armv7em") != NULL &&
        strstr(ctx->swift_target, "eabihf") != NULL) {
        return "armv7em-none-none-eabi";
    }

    // UNO R4 Minima: force ...eabi for swiftc (never eabihf)
    if (is_renesas_uno_fqbn(ctx) && is_cpu_cortex_m4(ctx)) {
        return "armv7em-none-none-eabi";
    }

    return ctx->swift_target[0] ? ctx->swift_target : "armv7-none-none-eabi";
}

/*
  Float ABI matching strategy:

  UNO R4 Minima:
    - Renesas core is hard-float. We make Swift compile with hard-float calling convention.

  GIGA:
    - Arduino mbed_giga often expects softfp ABI.
    - Keep Swift at softfp to reduce ABI mismatch risk.
    - mfpu differs by target_core:
        cm7 -> fpv5-d16
        cm4 -> fpv4-sp-d16

  Others (Due, etc):
    - no float flags (toolchain defaults)
*/
static void swift_xcc_float_flags(const BuildContext* ctx, char* out, size_t cap) {
    if (!out || cap == 0) return;
    out[0] = 0;

    // UNO R4: hard-float
    if (is_renesas_uno_fqbn(ctx) && is_cpu_cortex_m4(ctx)) {
        snprintf(out, cap,
            "-Xcc -mfloat-abi=hard "
            "-Xcc -mfpu=fpv4-sp-d16 "
        );
        return;
    }

    // GIGA: softfp, choose mfpu based on board options (target_core)
    if (is_mbed_giga_fqbn(ctx)) {
        const char* opts = (ctx->board_opts_csv[0] ? ctx->board_opts_csv : "target_core=cm7");
        const int is_cm4 = str_contains_kv(opts, "target_core=cm4");

        snprintf(out, cap,
            "-Xcc -mfloat-abi=softfp "
            "-Xcc -mfpu=%s ",
            is_cm4 ? "fpv4-sp-d16" : "fpv5-d16"
        );
        return;
    }

    // Due / others: no extra float flags
}

static int append_main_swift(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!file_exists(ctx->main_swift_path)) {
        log_error("Missing main.swift at project root: %s", ctx->main_swift_path);
        return 0;
    }

    size_t need = strlen(ctx->swift_args) + strlen(ctx->main_swift_path) + 8;
    if (need >= sizeof(ctx->swift_args)) {
        log_error("Args buffer overflow adding main.swift");
        return 0;
    }

    strcat(ctx->swift_args, "\"");
    strcat(ctx->swift_args, ctx->main_swift_path);
    strcat(ctx->swift_args, "\" ");

    return 1;
}

// Build a safe string for arduino-cli --board-options "<csv>"
// - Filters to: [A-Za-z0-9_.,=-]
// - Converts ';' to ',' (accept both notations)
// - Drops spaces/quotes and any shell-dangerous chars
static void sanitize_board_options_csv(const char* in, char* out, size_t cap) {
    if (!out || cap == 0) return;
    out[0] = 0;

    if (!in || !in[0]) return;

    size_t w = 0;
    for (size_t i = 0; in[i] && w + 1 < cap; i++) {
        unsigned char c = (unsigned char)in[i];

        if (c == ';') c = ',';

        const int ok =
            (c >= 'a' && c <= 'z') ||
            (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9') ||
            (c == '_') || (c == '-') ||
            (c == ',') || (c == '.') ||
            (c == '='); // key=value pairs

        if (!ok) continue;

        out[w++] = (char)c;
    }
    out[w] = 0;

    // trim trailing commas
    while (w > 0 && out[w - 1] == ',') {
        out[--w] = 0;
    }
}

// ------------------------------------------------------------
// Step 5
// ------------------------------------------------------------

int cmd_build_step_5_compile_and_arduino_cli(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!append_main_swift(ctx)) return 0;

    const int renesas = is_renesas_uno_fqbn(ctx);
    const int giga    = is_mbed_giga_fqbn(ctx);

    // --------------------------------------------------
    // 1) swiftc compile
    // --------------------------------------------------
    build_ctx_set_step_log(ctx, "build_swiftc");
    {
        char swiftc_cmd[260000];

        const char* swift_target = swift_target_for_swiftc(ctx);

        char xcc_float[512];
        swift_xcc_float_flags(ctx, xcc_float, sizeof(xcc_float));

        snprintf(swiftc_cmd, sizeof(swiftc_cmd),
            "%s "
            "-target %s -O -wmo -parse-as-library "
            "-Xfrontend -enable-experimental-feature -Xfrontend Embedded "
            "-Xfrontend -target-cpu -Xfrontend %s "
            "-Xfrontend -disable-stack-protector "
            "-Xcc -mcpu=%s -Xcc -mthumb -Xcc -ffreestanding -Xcc -fno-builtin "
            "-Xcc -fdata-sections -Xcc -ffunction-sections "
            "%s"
            "%s "
            "-c -o \"%s\"",
            ctx->swiftc,
            swift_target,
            ctx->cpu,
            ctx->cpu,
            xcc_float,
            ctx->swift_args,
            ctx->swift_obj_path
        );

        log_cmd("%s", swiftc_cmd);
        int rc = proc_run_tee(swiftc_cmd, ctx->last_log_path, log_is_verbose());
        if (rc != 0) {
            log_error("Swift compile failed (log: %s)", ctx->last_log_path);
            log_sep();
            proc_tail_file(ctx->last_log_path, 140);
            log_sep();
            return 0;
        }
    }

    // --------------------------------------------------
    // 2) arduino-cli compile
    //
    // Goals:
    // - Same script works for Due, Minima, Giga and future boards.
    // - No fragile embedded quoting in build-property values.
    // - Inject Swift object into final ELF link step reliably.
    // --------------------------------------------------
    build_ctx_set_step_log(ctx, "build_arduino_cli");
    {
        char cli_cmd[32000];

        // Some cores choke on -fno-short-enums or don't need it.
        // Keep your current policy but make it data-driven later if needed.
        const char* c_extra   = (renesas || giga) ? "" : "-fno-short-enums";
        const char* cpp_extra = (renesas || giga) ? "" : "-fno-short-enums";
        const char* s_extra   = "";

        // For some legacy cores (Due/SAM) you used this defsym. Keep it for non-renesas/non-giga.
        const char* link_tail = (renesas || giga) ? "" : " -Wl,--defsym=end=_end";

        // Board options (if any) are always optional and should be safe to pass.
        char safe_opts[512];
        sanitize_board_options_csv(ctx->board_opts_csv, safe_opts, sizeof(safe_opts));
        const int has_board_opts = (safe_opts[0] != 0);

        // IMPORTANT: do NOT wrap this in extra quotes inside the property value.
        // Otherwise gcc receives "obj + linker flags" as one single file path.
        char elf_extra[2048];
        snprintf(elf_extra, sizeof(elf_extra), "%s%s", ctx->swift_obj_path, link_tail);

        snprintf(cli_cmd, sizeof(cli_cmd),
            "arduino-cli compile --clean "
            "--fqbn \"%s\" "
            "%s%s%s "
            "--build-path \"%s\" "
            "--build-property \"compiler.c.extra_flags=%s\" "
            "--build-property \"compiler.cpp.extra_flags=%s\" "
            "--build-property \"compiler.S.extra_flags=%s\" "
            "--build-property \"compiler.c.elf.extra_flags=%s\" "
            "\"%s\"",
            ctx->fqbn_final,
            (has_board_opts ? "--board-options \"" : ""),
            (has_board_opts ? safe_opts : ""),
            (has_board_opts ? "\" " : ""),
            ctx->ard_build_dir,
            c_extra,
            cpp_extra,
            s_extra,
            elf_extra,
            ctx->sketch_dir
        );

        if (has_board_opts) {
            log_info("Board options: %s", safe_opts);
        }

        log_cmd("%s", cli_cmd);
        int rc = proc_run_tee(cli_cmd, ctx->last_log_path, log_is_verbose());
        if (rc != 0) {
            log_error("arduino-cli compile failed (log: %s)", ctx->last_log_path);
            log_sep();
            proc_tail_file(ctx->last_log_path, 180);
            log_sep();
            return 0;
        }
    }

    log_info("Build complete");
    log_info("Artifacts: %s", ctx->ard_build_dir);
    return 1;
}