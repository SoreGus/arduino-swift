// step_5_compile_and_arduino_cli.c
#include "step_5_compile_and_arduino_cli.h"

#include "common/build_log.h"
#include "common/proc_helpers.h"

#include "util.h"

#include <string.h>
#include <stdio.h>

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

int cmd_build_step_5_compile_and_arduino_cli(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!append_main_swift(ctx)) return 0;

    // swiftc
    build_ctx_set_step_log(ctx, "build_swiftc");
    {
        char swiftc_cmd[260000];
        snprintf(swiftc_cmd, sizeof(swiftc_cmd),
          "%s "
          "-target %s -O -wmo -parse-as-library "
          "-Xfrontend -enable-experimental-feature -Xfrontend Embedded "
          "-Xfrontend -target-cpu -Xfrontend %s "
          "-Xfrontend -disable-stack-protector "
          "-Xcc -mcpu=%s -Xcc -mthumb -Xcc -ffreestanding -Xcc -fno-builtin "
          "-Xcc -fdata-sections -Xcc -ffunction-sections -Xcc -fno-short-enums "
          "%s "
          "-c -o \"%s\"",
          ctx->swiftc,
          ctx->swift_target,
          ctx->cpu,
          ctx->cpu,
          ctx->swift_args,
          ctx->swift_obj_path
        );

        log_cmd("%s", swiftc_cmd);
        int rc = proc_run_tee(swiftc_cmd, ctx->last_log_path, log_is_verbose());
        if (rc != 0) {
            log_error("Swift compile failed (log: %s)", ctx->last_log_path);
            log_sep();
            proc_tail_file(ctx->last_log_path, 120);
            log_sep();
            return 0;
        }
    }

    /*
      arduino-cli:
      - Staged tool/runtime libs are under ctx->sketch_dir/libraries
      - User Arduino libs are expected to be discovered from the user's sketchbook
        (we do NOT stage/copy them to avoid duplicate compilation).
    */
    build_ctx_set_step_log(ctx, "build_arduino_cli");
    {
        char cli_cmd[20000];
        snprintf(cli_cmd, sizeof(cli_cmd),
        "arduino-cli compile --clean "
        "--fqbn \"%s\" "
        "--build-path \"%s\" "
        "--build-property \"compiler.c.extra_flags=-fno-short-enums\" "
        "--build-property \"compiler.cpp.extra_flags=-fno-short-enums\" "
        "--build-property \"compiler.c.elf.extra_flags=\\\"%s\\\" -Wl,--defsym=end=_end\" "
        "\"%s\"",
        ctx->fqbn,
        ctx->ard_build_dir,
        ctx->swift_obj_path,
        ctx->sketch_dir
        );

        log_cmd("%s", cli_cmd);
        int rc = proc_run_tee(cli_cmd, ctx->last_log_path, log_is_verbose());
        if (rc != 0) {
            log_error("arduino-cli compile failed (log: %s)", ctx->last_log_path);
            log_sep();
            proc_tail_file(ctx->last_log_path, 160);
            log_sep();
            return 0;
        }
    }

    log_info("Build complete");
    log_info("Artifacts: %s", ctx->ard_build_dir);
    return 1;
}