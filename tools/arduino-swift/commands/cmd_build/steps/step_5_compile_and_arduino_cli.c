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
    return (ctx->fqbn[0] && strstr(ctx->fqbn, "renesas_uno") != NULL);
}

static int is_cpu_cortex_m4(const BuildContext* ctx) {
    if (!ctx) return 0;
    return (ctx->cpu[0] && strstr(ctx->cpu, "cortex-m4") != NULL);
}

/*
  Swift embedded stdlib availability:
    - Your toolchain typically has: armv7em-none-none-eabi
    - It does NOT have:            armv7em-none-none-eabihf  (your error proved this)

  For UNO R4 Minima:
    - We keep Swift triple as ...eabi (so the module 'Swift' exists)
    - But we still compile with hard-float ABI flags so the produced .o uses VFP args,
      matching the Arduino Renesas core build (which is hard-float).
*/
static const char* swift_target_for_swiftc(const BuildContext* ctx) {
    if (!ctx) return "armv7-none-none-eabi";

    // If user/boards.json ever injects eabihf by mistake, fix only for swiftc:
    if (strstr(ctx->swift_target, "armv7em") && strstr(ctx->swift_target, "eabihf")) {
        return "armv7em-none-none-eabi";
    }

    // Renesas UNO R4: force ...eabi (never eabihf) for swiftc
    if (is_renesas_uno_fqbn(ctx) && is_cpu_cortex_m4(ctx)) {
        return "armv7em-none-none-eabi";
    }

    return ctx->swift_target;
}

static void swift_hardfloat_xcc_flags(const BuildContext* ctx, char* out, size_t cap) {
    if (!out || cap == 0) return;
    out[0] = 0;

    // boards.json (R4Minima) intention:
    //   float_abi = hard
    //   fpu       = fpv4-sp-d16
    if (is_renesas_uno_fqbn(ctx) && is_cpu_cortex_m4(ctx)) {
        // IMPORTANT: These affect the produced object ABI (VFP args) even with ...eabi triple.
        snprintf(out, cap,
            "-Xcc -mfloat-abi=hard "
            "-Xcc -mfpu=fpv4-sp-d16 "
        );
    }
}

static int append_main_swift(BuildContext* ctx) {
    if (!file_exists(ctx->main_swift_path)) {
        log_error("Missing main.swift at project root: %s", ctx->main_swift_path);
        return 0;
    }

    size_t need = strlen(ctx->swift_args) + strlen(ctx->main_swift_path) + 4 + 2;
    if (need >= sizeof(ctx->swift_args)) {
        log_error("Args buffer overflow adding main.swift");
        return 0;
    }

    strcat(ctx->swift_args, "\"");
    strcat(ctx->swift_args, ctx->main_swift_path);
    strcat(ctx->swift_args, "\" ");

    return 1;
}

// ------------------------------------------------------------
// Step 5
// ------------------------------------------------------------

int cmd_build_step_5_compile_and_arduino_cli(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!append_main_swift(ctx)) return 0;

    const int renesas = is_renesas_uno_fqbn(ctx);

    // --------------------------------------------------
    // 1) swiftc compile
    //
    // - Keep Swift target to a triple that exists in embedded stdlib (..eabi)
    // - For Renesas UNO R4: still compile with hard-float ABI flags (VFP args)
    //   to match the Arduino core and avoid "uses VFP register arguments ... does not".
    // --------------------------------------------------
    build_ctx_set_step_log(ctx, "build_swiftc");
    {
        char swiftc_cmd[260000];

        const char* swift_target = swift_target_for_swiftc(ctx);

        char xcc_fpu[512];
        swift_hardfloat_xcc_flags(ctx, xcc_fpu, sizeof(xcc_fpu));

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
          xcc_fpu,
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
    // 2) arduino-cli build
    //
    // Key points:
    // - DO NOT force Renesas core to soft/softfp (that caused the mismatch direction).
    // - Just inject Swift object into link step.
    // - Keep your -fno-short-enums for non-Renesas (Due), but don't mess with float ABI here.
    // --------------------------------------------------
    build_ctx_set_step_log(ctx, "build_arduino_cli");
    {
        char cli_cmd[24000];

        const char* c_extra   = renesas ? "" : "-fno-short-enums";
        const char* cpp_extra = renesas ? "" : "-fno-short-enums";
        const char* s_extra   = "";

        // Linker extra: keep your defsym only on non-Renesas.
        const char* link_tail = renesas ? "" : " -Wl,--defsym=end=_end";

        snprintf(cli_cmd, sizeof(cli_cmd),
            "arduino-cli compile --clean "
            "--fqbn \"%s\" "
            "--build-path \"%s\" "
            "--build-property \"compiler.c.extra_flags=%s\" "
            "--build-property \"compiler.cpp.extra_flags=%s\" "
            "--build-property \"compiler.S.extra_flags=%s\" "
            "--build-property \"compiler.c.elf.extra_flags=\\\"%s\\\"%s\" "
            "\"%s\"",
            ctx->fqbn,
            ctx->ard_build_dir,
            c_extra,
            cpp_extra,
            s_extra,
            ctx->swift_obj_path,
            link_tail,
            ctx->sketch_dir
        );

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