// build_context.c
#include "build_context.h"

#include "build_log.h"
#include "json_helpers.h"
#include "fs_helpers.h"
#include "util.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static void trim_nl(char* s) {
    if (!s) return;
    char* p = strchr(s, '\n');
    if (p) *p = 0;
    p = strchr(s, '\r');
    if (p) *p = 0;
}

static void zero_ctx(BuildContext* ctx) {
    memset(ctx, 0, sizeof(*ctx));
}

static int fqbn_to_core(const char* fqbn_any, char* out, size_t cap) {
    if (!out || cap == 0) return 0;
    out[0] = 0;
    if (!fqbn_any || !fqbn_any[0]) return 0;

    const char* first = strchr(fqbn_any, ':');
    if (!first) return 0;
    const char* second = strchr(first + 1, ':');
    if (!second) return 0;

    size_t n = (size_t)(second - fqbn_any);
    if (n >= cap) n = cap - 1;
    memcpy(out, fqbn_any, n);
    out[n] = 0;
    return out[0] ? 1 : 0;
}

static void board_opts_append(char* csv, size_t cap, const char* k, const char* v) {
    if (!csv || cap == 0 || !k || !v || !k[0] || !v[0]) return;

    size_t len = strlen(csv);
    if (len == 0) {
        snprintf(csv, cap, "%s=%s", k, v);
    } else {
        snprintf(csv + len, cap - len, ",%s=%s", k, v);
    }
}

static void build_board_opts_csv(
    BuildContext* ctx,
    const char* def_ob, const char* def_oe,
    const char* cfg_ob, const char* cfg_oe
) {
    // Deterministic merge for known keys.
    // Order: config overrides defaults.
    // Keys we care (Giga): target_core, split, security
    char v_def[128], v_cfg[128];

    ctx->board_opts_csv[0] = 0;

    const char* keys[] = { "target_core", "split", "security" };
    for (int i = 0; i < 3; i++) {
        const char* k = keys[i];
        v_def[0] = 0;
        v_cfg[0] = 0;

        if (def_ob && def_oe) (void)asw_json_get_string_in_span(def_ob, def_oe, k, v_def, sizeof(v_def));
        if (cfg_ob && cfg_oe) (void)asw_json_get_string_in_span(cfg_ob, cfg_oe, k, v_cfg, sizeof(v_cfg));

        const char* chosen = v_cfg[0] ? v_cfg : (v_def[0] ? v_def : NULL);
        if (chosen) board_opts_append(ctx->board_opts_csv, sizeof(ctx->board_opts_csv), k, chosen);
    }
}

int build_ctx_init(BuildContext* ctx) {
    if (!ctx) return 0;
    zero_ctx(ctx);

    const char* env_root = getenv("ARDUINO_SWIFT_ROOT");
    if (env_root && env_root[0]) {
        strncpy(ctx->project_root, env_root, sizeof(ctx->project_root) - 1);
    } else {
        if (!cwd_dir(ctx->project_root, sizeof(ctx->project_root))) {
            strncpy(ctx->project_root, ".", sizeof(ctx->project_root) - 1);
        }
    }

    const char* tr = exe_dir();
    if (!tr || !tr[0]) return 0;
    strncpy(ctx->tool_root, tr, sizeof(ctx->tool_root) - 1);

    // Keep current tree name to avoid breaking: arduino/commom
    if (!path_join(ctx->runtime_arduino, sizeof(ctx->runtime_arduino), ctx->tool_root, "arduino/commom")) return 0;
    if (!path_join(ctx->runtime_swift, sizeof(ctx->runtime_swift), ctx->tool_root, "swift")) return 0;

    snprintf(ctx->config_path, sizeof(ctx->config_path), "%s/config.json", ctx->project_root);
    snprintf(ctx->boards_path, sizeof(ctx->boards_path), "%s/boards.json", ctx->tool_root);

    snprintf(ctx->build_dir, sizeof(ctx->build_dir), "%s/build", ctx->project_root);
    snprintf(ctx->sketch_dir, sizeof(ctx->sketch_dir), "%s/sketch", ctx->build_dir);
    snprintf(ctx->ard_build_dir, sizeof(ctx->ard_build_dir), "%s/arduino_build", ctx->build_dir);

    snprintf(ctx->logs_dir, sizeof(ctx->logs_dir), "%s/logs", ctx->build_dir);

    snprintf(ctx->swift_obj_path, sizeof(ctx->swift_obj_path), "%s/ArduinoSwiftApp.o", ctx->sketch_dir);
    snprintf(ctx->main_swift_path, sizeof(ctx->main_swift_path), "%s/main.swift", ctx->project_root);

    // Resolve swiftc (override supported)
    {
        char pfile[1024];
        snprintf(pfile, sizeof(pfile), "%s/.swiftc_path", ctx->build_dir);

        const char* env = getenv("SWIFTC");
        if (env && env[0]) {
            strncpy(ctx->swiftc, env, sizeof(ctx->swiftc) - 1);
        } else if (file_exists(pfile)) {
            char* s = read_file(pfile);
            if (s) {
                trim_nl(s);
                strncpy(ctx->swiftc, s, sizeof(ctx->swiftc) - 1);
                free(s);
            }
        } else {
            strncpy(ctx->swiftc, "swiftc", sizeof(ctx->swiftc) - 1);
        }
    }

    return 1;
}

int build_ctx_load_json(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!file_exists(ctx->config_path)) {
        log_error("config.json not found at: %s", ctx->config_path);
        return 0;
    }
    if (!file_exists(ctx->boards_path)) {
        log_error("boards.json not found at tool root: %s", ctx->boards_path);
        return 0;
    }

    ctx->cfg_json = read_file(ctx->config_path);
    ctx->boards_json = read_file(ctx->boards_path);

    if (!ctx->cfg_json || !ctx->boards_json) {
        log_error("Failed to read config/boards json");
        return 0;
    }
    return 1;
}

int build_ctx_select_board_and_parse(BuildContext* ctx) {
    if (!ctx || !ctx->cfg_json || !ctx->boards_json) return 0;

    // Defaults
    ctx->user_arduino_lib_dir[0] = 0;
    ctx->float_abi[0] = 0;
    ctx->fpu[0] = 0;
    ctx->api[0] = 0;
    ctx->board_opts_csv[0] = 0;

    // Optional override: arduino_lib_dir
    if (!asw_json_get_string(ctx->cfg_json, "arduino_lib_dir",
                            ctx->user_arduino_lib_dir, sizeof(ctx->user_arduino_lib_dir))) {
        const char* home = getenv("HOME");
        if (home && home[0]) {
            snprintf(ctx->user_arduino_lib_dir, sizeof(ctx->user_arduino_lib_dir),
                     "%s/Documents/Arduino/libraries", home);
            if (!dir_exists(ctx->user_arduino_lib_dir)) ctx->user_arduino_lib_dir[0] = 0;
        }
    }

    // libs
    ctx->swift_lib_count   = asw_parse_json_string_array(ctx->cfg_json, "lib",        ctx->swift_libs,   64);
    ctx->arduino_lib_count = asw_parse_json_string_array(ctx->cfg_json, "arduino_lib", ctx->arduino_libs, 64);

    // board
    if (!asw_json_get_string(ctx->cfg_json, "board", ctx->board, sizeof(ctx->board))) {
        log_error("config.json missing board");
        return 0;
    }

    // board object span from boards.json
    const char* ob = NULL;
    const char* oe = NULL;
    if (!asw_boards_get_object_span(ctx->boards_json, ctx->board, &ob, &oe)) {
        log_error("Invalid board: %s", ctx->board);
        return 0;
    }

    // ---- Read board properties ----
    ctx->fqbn[0] = 0;
    ctx->fqbn_base[0] = 0;
    ctx->fqbn_final[0] = 0;
    ctx->core[0] = 0;

    // Legacy support:
    // - Prefer "fqbn_base"
    // - Else fallback to "fqbn"
    (void)asw_json_get_string_in_span(ob, oe, "fqbn_base", ctx->fqbn_base, sizeof(ctx->fqbn_base));
    (void)asw_json_get_string_in_span(ob, oe, "fqbn",      ctx->fqbn,      sizeof(ctx->fqbn));

    if (!ctx->fqbn_base[0] && ctx->fqbn[0]) {
        strncpy(ctx->fqbn_base, ctx->fqbn, sizeof(ctx->fqbn_base) - 1);
    }

    if (!ctx->fqbn_base[0]) {
        log_error("boards.json missing fqbn/fqbn_base for board: %s", ctx->board);
        return 0;
    }

    // IMPORTANT: fqbn_final is ALWAYS base (no options appended) to avoid duplication.
    strncpy(ctx->fqbn_final, ctx->fqbn_base, sizeof(ctx->fqbn_final) - 1);

    // core + api
    (void)asw_json_get_string_in_span(ob, oe, "core", ctx->core, sizeof(ctx->core));
    if (!ctx->core[0]) (void)fqbn_to_core(ctx->fqbn_base, ctx->core, sizeof(ctx->core));

    (void)asw_json_get_string_in_span(ob, oe, "api", ctx->api, sizeof(ctx->api));

    // toolchain info
    if (!asw_json_get_string_in_span(ob, oe, "swift_target", ctx->swift_target, sizeof(ctx->swift_target))) {
        strncpy(ctx->swift_target, "armv7-none-none-eabi", sizeof(ctx->swift_target) - 1);
    }
    if (!asw_json_get_string_in_span(ob, oe, "cpu", ctx->cpu, sizeof(ctx->cpu))) {
        strncpy(ctx->cpu, "cortex-m3", sizeof(ctx->cpu) - 1);
    }
    (void)asw_json_get_string_in_span(ob, oe, "float_abi", ctx->float_abi, sizeof(ctx->float_abi));
    (void)asw_json_get_string_in_span(ob, oe, "fpu",       ctx->fpu,       sizeof(ctx->fpu));

    // ---- Merge board_options (config overrides defaults) ----
    const char* def_ob = NULL;
    const char* def_oe = NULL;
    (void)asw_json_get_object_span_in_span(ob, oe, "default_board_options", &def_ob, &def_oe);

    const char* cfg_ob2 = NULL;
    const char* cfg_oe2 = NULL;
    (void)asw_json_get_object_span(ctx->cfg_json, "board_options", &cfg_ob2, &cfg_oe2);

    build_board_opts_csv(ctx, def_ob, def_oe, cfg_ob2, cfg_oe2);

    return 1;
}

int build_ctx_prepare_dirs(BuildContext* ctx) {
    if (!ctx) return 0;

    (void)fs_rm_rf(ctx->sketch_dir);
    (void)fs_rm_rf(ctx->ard_build_dir);

    if (!fs_mkdir_p(ctx->build_dir)) return 0;
    if (!fs_mkdir_p(ctx->sketch_dir)) return 0;
    if (!fs_mkdir_p(ctx->ard_build_dir)) return 0;
    if (!fs_mkdir_p(ctx->logs_dir)) return 0;

    char libs_root[1024];
    snprintf(libs_root, sizeof(libs_root), "%s/libraries", ctx->sketch_dir);
    if (!fs_mkdir_p(libs_root)) return 0;

    return 1;
}

void build_ctx_destroy(BuildContext* ctx) {
    if (!ctx) return;
    if (ctx->cfg_json) free(ctx->cfg_json);
    if (ctx->boards_json) free(ctx->boards_json);
    zero_ctx(ctx);
}

void build_ctx_set_step_log(BuildContext* ctx, const char* name) {
    if (!ctx) return;
    if (!name) name = "step";
    snprintf(ctx->last_log_path, sizeof(ctx->last_log_path), "%s/%s.log", ctx->logs_dir, name);
}