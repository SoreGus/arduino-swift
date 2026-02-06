// upload_step_3_detect_port_and_upload.c
#include "upload_step_3_detect_port_and_upload.h"

#include "common/build_log.h"
#include "common/fs_helpers.h"
#include "util.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// ------------------------------------------------------------
// Diagnostics
// ------------------------------------------------------------

static void debug_dump_port_diagnostics(void) {
    log_info("Port diagnostics:");
    log_cmd("arduino-cli board list");
    (void)run_cmd(
        "echo \"--- arduino-cli board list ---\"; "
        "arduino-cli board list 2>/dev/null || true; "
        "echo \"--- end ---\""
    );

#if defined(__APPLE__)
    log_cmd("ls /dev/cu.* /dev/tty.* (top 120)");
    (void)run_cmd(
        "echo \"--- /dev candidates (mac) ---\"; "
        "ls -1 /dev/cu.* /dev/tty.* 2>/dev/null | sort | head -n 120; "
        "echo \"--- end ---\""
    );
#else
    log_cmd("ls /dev/ttyACM* /dev/ttyUSB*");
    (void)run_cmd(
        "echo \"--- /dev candidates (linux) ---\"; "
        "ls -1 /dev/ttyACM* /dev/ttyUSB* 2>/dev/null | sort | head -n 120; "
        "echo \"--- end ---\""
    );
#endif
}

// ------------------------------------------------------------
// Board helpers
// ------------------------------------------------------------

static const char* pick_fqbn_for_match(const BuildContext* ctx) {
    if (!ctx) return NULL;
    if (ctx->fqbn_final[0]) return ctx->fqbn_final;
    if (ctx->fqbn_base[0])  return ctx->fqbn_base;
    if (ctx->fqbn[0])       return ctx->fqbn;
    return NULL;
}

// Robust RP2040 matcher.
// Accepts any fqbn containing "rp2040:rp2040:".
static int is_rp2040_fqbn(const char* fqbn) {
    if (!fqbn || !fqbn[0]) return 0;
    return strstr(fqbn, "rp2040:rp2040:") != NULL;
}

#if defined(__APPLE__)
static const char* rp2040_boot_drive_path(void) {
    return "/Volumes/RPI-RP2";
}

static int rp2040_boot_drive_present(void) {
    return dir_exists(rp2040_boot_drive_path());
}
#endif

// ------------------------------------------------------------
// Port selection
// ------------------------------------------------------------

static int choose_port(BuildContext* ctx, char* out, size_t cap) {
    if (!out || cap == 0) return 0;
    out[0] = 0;

    // 1) Env override
    const char* env = getenv("PORT");
    if (env && env[0]) {
        strncpy(out, env, cap - 1);
        out[cap - 1] = 0;
        return 1;
    }

    const char* tmp = "/tmp/arduino_swift_port.txt";
    char cmd[8192];

    const char* fqbn = pick_fqbn_for_match(ctx);

    // 2) Match row by FQBN and get col1
    if (fqbn && fqbn[0]) {
        snprintf(cmd, sizeof(cmd),
            "arduino-cli board list 2>/dev/null | "
            "awk -v fqbn=\"%s\" '($0 ~ fqbn) { print $1; exit 0 }' > \"%s\"; "
            "test -s \"%s\"",
            fqbn, tmp, tmp
        );

        if (run_cmd(cmd) == 0) {
            FILE* f = fopen(tmp, "rb");
            if (f) {
                char line[512] = {0};
                if (fgets(line, sizeof(line), f)) {
                    fclose(f);

                    while (line[0] == ' ' || line[0] == '\t') memmove(line, line + 1, strlen(line));
                    for (char* p = line; *p; p++) {
                        if (*p == '\n' || *p == '\r' || *p == ' ' || *p == '\t') { *p = 0; break; }
                    }

                    if (line[0]) {
                        strncpy(out, line, cap - 1);
                        out[cap - 1] = 0;
                        return 1;
                    }
                } else {
                    fclose(f);
                }
            }
        }
    }

    // 3) Extract /dev/... from board list
    const char* dev_extract =
        "grep -Eo '/dev/(cu\\.[A-Za-z0-9._-]+|tty\\.[A-Za-z0-9._-]+|ttyACM[0-9]+|ttyUSB[0-9]+)'";
    const char* dev_filter =
        "grep -E '^/dev/("
        "cu\\.(usbmodem|usbserial|wchusbserial|SLAB_USBtoUART)"
        "|tty\\.(usbmodem|usbserial|wchusbserial|SLAB_USBtoUART)"
        "|ttyACM|ttyUSB"
        ")'";

    snprintf(cmd, sizeof(cmd),
        "arduino-cli board list 2>/dev/null | %s | %s | head -n 1 > \"%s\"; test -s \"%s\"",
        dev_extract, dev_filter, tmp, tmp
    );

    int rc = run_cmd(cmd);

#if defined(__APPLE__)
    if (rc != 0) {
        snprintf(cmd, sizeof(cmd),
            "(ls -1 "
            "/dev/cu.usbmodem* /dev/tty.usbmodem* "
            "/dev/cu.usbserial* /dev/tty.usbserial* "
            "/dev/cu.wchusbserial* /dev/tty.wchusbserial* "
            "/dev/cu.SLAB_USBtoUART* /dev/tty.SLAB_USBtoUART* "
            "2>/dev/null | head -n 1) > \"%s\"; test -s \"%s\"",
            tmp, tmp
        );
        rc = run_cmd(cmd);
    }

    if (rc != 0) {
        snprintf(cmd, sizeof(cmd),
            "(ls -1 /dev/cu.* /dev/tty.* 2>/dev/null | "
            "grep -E '(usbmodem|usbserial|wchusbserial|SLAB_USBtoUART)' | head -n 1) > \"%s\"; "
            "test -s \"%s\"",
            tmp, tmp
        );
        rc = run_cmd(cmd);
    }
#else
    if (rc != 0) {
        snprintf(cmd, sizeof(cmd),
            "(ls -1 /dev/ttyACM* /dev/ttyUSB* 2>/dev/null | head -n 1) > \"%s\"; test -s \"%s\"",
            tmp, tmp
        );
        rc = run_cmd(cmd);
    }
#endif

    if (rc != 0) return 0;

    FILE* f = fopen(tmp, "rb");
    if (!f) return 0;

    char line[512] = {0};
    if (!fgets(line, sizeof(line), f)) {
        fclose(f);
        return 0;
    }
    fclose(f);

    while (line[0] == ' ' || line[0] == '\t') memmove(line, line + 1, strlen(line));
    for (char* p = line; *p; p++) {
        if (*p == '\n' || *p == '\r' || *p == ' ' || *p == '\t') { *p = 0; break; }
    }

    if (!line[0]) return 0;

    strncpy(out, line, cap - 1);
    out[cap - 1] = 0;
    return 1;
}

// ------------------------------------------------------------
// Artifact checks
// ------------------------------------------------------------

static int has_build_artifacts(const char* dir) {
    if (!dir || !dir[0] || !dir_exists(dir)) return 0;

    char cmd[4096];
    snprintf(cmd, sizeof(cmd),
             "cd \"%s\" 2>/dev/null && "
             "find . -maxdepth 8 -type f \\( "
             "-name \"*.bin\" -o -name \"*.hex\" -o -name \"*.uf2\" -o -name \"*.elf\" "
             "\\) -print -quit | grep -q .",
             dir);

    return run_cmd(cmd) == 0;
}

static void debug_list_artifacts(const char* dir) {
    if (!dir || !dir[0]) return;

    log_info("Artifact scan under: %s", dir);

    char cmd[4096];
    snprintf(cmd, sizeof(cmd),
             "echo \"--- artifacts (bin/hex/uf2/elf) ---\"; "
             "cd \"%s\" 2>/dev/null && "
             "find . -maxdepth 8 -type f \\( -name \"*.bin\" -o -name \"*.hex\" -o -name \"*.uf2\" -o -name \"*.elf\" \\) "
             "| sed 's|^\\./||' | sort; "
             "echo \"--- end artifacts ---\"",
             dir);
    run_cmd(cmd);
}

// ------------------------------------------------------------
// Step 3: detect port + upload
// ------------------------------------------------------------

int upload_step_3_detect_port_and_upload(BuildContext* ctx) {
    if (!ctx) return 0;

    const char* fqbn = pick_fqbn_for_match(ctx);
    if (!fqbn || !fqbn[0]) {
        log_error("FQBN is empty. Refusing to upload.\n"
                  "Fix: ensure board selection populates fqbn_base/fqbn_final.");
        return 0;
    }

    log_info("DEBUG fqbn resolved: '%s'", fqbn);
    log_info("DEBUG is_rp2040: %d", is_rp2040_fqbn(fqbn));

    if (!ctx->ard_build_dir[0] || !dir_exists(ctx->ard_build_dir) || !has_build_artifacts(ctx->ard_build_dir)) {
        log_error("No build artifacts found under: %s", ctx->ard_build_dir[0] ? ctx->ard_build_dir : "(empty)");
        debug_list_artifacts(ctx->ard_build_dir);
        log_error("Fix: run `arduino-swift build` first (it must place .bin/.hex/.uf2/.elf inside arduino_build).");
        return 0;
    }

    char cmd[8192];

    // RP2040: always upload WITHOUT -p
    if (is_rp2040_fqbn(fqbn)) {
#if defined(__APPLE__)
        const char* rp_port = rp2040_boot_drive_path();
        if (!rp2040_boot_drive_present()) {
            log_error("RP2040 boot drive not found (%s).\n"
                      "Fix: hold BOOTSEL while connecting/resetting the Pico, wait mount, then retry upload.",
                      rp_port);
            run_cmd("echo \"--- /Volumes ---\"; ls -la /Volumes 2>/dev/null || true; echo \"--- end ---\"");
            return 0;
        }
#endif

        log_info("Uploading (RP2040 UF2 mode)...");
        log_info("FQBN: %s", fqbn);
        log_info("Input dir: %s", ctx->ard_build_dir);

        if (ctx->board_opts_csv[0]) {
#if defined(__APPLE__)
            snprintf(cmd, sizeof(cmd),
                     "arduino-cli upload "
                     "-p \"%s\" "
                     "--fqbn \"%s\" "
                     "--board-options \"%s\" "
                     "--input-dir \"%s\" "
                     "\"%s\"",
                     rp_port, fqbn, ctx->board_opts_csv, ctx->ard_build_dir, ctx->sketch_dir);
#else
            snprintf(cmd, sizeof(cmd),
                     "arduino-cli upload "
                     "--fqbn \"%s\" "
                     "--board-options \"%s\" "
                     "--input-dir \"%s\" "
                     "\"%s\"",
                     fqbn, ctx->board_opts_csv, ctx->ard_build_dir, ctx->sketch_dir);
#endif
        } else {
#if defined(__APPLE__)
            snprintf(cmd, sizeof(cmd),
                     "arduino-cli upload "
                     "-p \"%s\" "
                     "--fqbn \"%s\" "
                     "--input-dir \"%s\" "
                     "\"%s\"",
                     rp_port, fqbn, ctx->ard_build_dir, ctx->sketch_dir);
#else
            snprintf(cmd, sizeof(cmd),
                     "arduino-cli upload "
                     "--fqbn \"%s\" "
                     "--input-dir \"%s\" "
                     "\"%s\"",
                     fqbn, ctx->ard_build_dir, ctx->sketch_dir);
#endif
        }

        log_cmd("%s", cmd);
        if (run_cmd(cmd) != 0) {
            log_error("arduino-cli upload failed (RP2040 mode)");
            log_info("Tip: ensure the board is in BOOTSEL mode and RPI-RP2 is mounted.");
            return 0;
        }

        log_info("Upload complete");
        return 1;
    }

    // Non-RP2040: use detected port
    char port[256];
    if (!choose_port(ctx, port, sizeof(port))) {
        log_error("Could not detect PORT.\n"
                  "Fix: set PORT explicitly, e.g.:\n"
                  "  PORT=/dev/cu.usbmodemXXXX arduino-swift upload\n"
                  "Tip: run `arduino-cli board list` to see the exact port name.");
        debug_dump_port_diagnostics();
        return 0;
    }

    // Hard block invalid token from board list parser
    if (strcmp(port, "Serial") == 0 || strcmp(port, "serial") == 0) {
        log_error("Invalid detected PORT token: '%s'. Refusing to upload with -p.", port);
        log_info("Tip: set PORT explicitly, e.g. PORT=/dev/cu.usbmodem1101");
        return 0;
    }

    log_info("Uploading...");
    log_info("FQBN: %s", fqbn);
    log_info("PORT: %s", port);
    log_info("Input dir: %s", ctx->ard_build_dir);

    if (ctx->board_opts_csv[0]) {
        snprintf(cmd, sizeof(cmd),
                 "arduino-cli upload "
                 "-p \"%s\" "
                 "--fqbn \"%s\" "
                 "--board-options \"%s\" "
                 "--input-dir \"%s\" "
                 "\"%s\"",
                 port, fqbn, ctx->board_opts_csv, ctx->ard_build_dir, ctx->sketch_dir);
    } else {
        snprintf(cmd, sizeof(cmd),
                 "arduino-cli upload "
                 "-p \"%s\" "
                 "--fqbn \"%s\" "
                 "--input-dir \"%s\" "
                 "\"%s\"",
                 port, fqbn, ctx->ard_build_dir, ctx->sketch_dir);
    }

    log_cmd("%s", cmd);
    if (run_cmd(cmd) != 0) {
        log_error("arduino-cli upload failed");
        log_info("Tip: on DFU boards (like UNO R4), try double-tap RESET to re-enter DFU, then re-run upload.");
        log_info("Tip: or set PORT explicitly (example DFU port can be like '1-1').");
        return 0;
    }

    log_info("Upload complete");
    return 1;
}