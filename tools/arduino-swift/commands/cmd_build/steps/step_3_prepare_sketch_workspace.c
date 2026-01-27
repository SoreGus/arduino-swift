// step_3_prepare_sketch_workspace.c
#include "step_3_prepare_sketch_workspace.h"

#include "common/build_log.h"
#include "common/fs_helpers.h"

#include "util.h"

#include <stdio.h>
#include <string.h>

static int ends_with(const char* s, const char* suf) {
    if (!s || !suf) return 0;
    size_t n = strlen(s);
    size_t m = strlen(suf);
    if (m > n) return 0;
    return memcmp(s + (n - m), suf, m) == 0;
}

static void normalize_common_dir(const char* runtime_arduino, char* out, size_t cap) {
    if (!out || cap == 0) return;
    out[0] = 0;

    if (!runtime_arduino || !runtime_arduino[0]) return;

    // build_context.c geralmente define runtime_arduino como ".../arduino/commom"
    // mas versões antigas podem definir como ".../arduino".
    // Aqui garantimos "common_dir" apontando para a pasta que realmente contém sketch.ino.
    if (ends_with(runtime_arduino, "/commom")) {
        strncpy(out, runtime_arduino, cap - 1);
        out[cap - 1] = 0;
    } else {
        snprintf(out, cap, "%s/commom", runtime_arduino);
    }
}

static int require_and_copy(const char* src_dir, const char* name, const char* dst_dir) {
    char src[1024], dst[1024];
    snprintf(src, sizeof(src), "%s/%s", src_dir, name);
    snprintf(dst, sizeof(dst), "%s/%s", dst_dir, name);

    if (!file_exists(src)) {
        log_error("Missing required file: %s", src);
        return 0;
    }
    if (!fs_copy_file(src, dst)) {
        log_error("Failed to copy %s -> %s", src, dst);
        return 0;
    }
    log_info("Using %s", name);
    return 1;
}

static int copy_first_existing_as(const char* src_dir,
                                 const char* const* candidates, int candidate_count,
                                 const char* dst_dir,
                                 const char* dst_name) {
    char src[1024], dst[1024];
    snprintf(dst, sizeof(dst), "%s/%s", dst_dir, dst_name);

    for (int i = 0; i < candidate_count; i++) {
        const char* name = candidates[i];
        if (!name || !name[0]) continue;

        snprintf(src, sizeof(src), "%s/%s", src_dir, name);
        if (!file_exists(src)) continue;

        if (!fs_copy_file(src, dst)) {
            log_error("Failed to copy %s -> %s", src, dst);
            return 0;
        }

        if (strcmp(name, dst_name) == 0) {
            log_info("Using %s", dst_name);
        } else {
            log_info("Using %s (from %s)", dst_name, name);
        }
        return 1;
    }

    // Helpful debug listing
    log_error("Missing required file: %s/%s (and fallbacks)", src_dir, dst_name);
    {
        char cmd[2048];
        snprintf(cmd, sizeof(cmd), "ls -la \"%s\" || true", src_dir);
        log_info("Runtime listing:");
        run_cmd(cmd);
    }
    return 0;
}

int cmd_build_step_3_prepare_sketch_workspace(BuildContext* ctx) {
    if (!ctx) return 0;

    if (!build_ctx_prepare_dirs(ctx)) {
        log_error("Failed to prepare build directories");
        return 0;
    }

    log_info("Preparing Arduino sketch workspace at: %s", ctx->sketch_dir);

    // New runtime layout: arduino/commom/
    // But build_context may already include /commom. Don't append twice.
    char common_dir[1024];
    normalize_common_dir(ctx->runtime_arduino, common_dir, sizeof(common_dir));

    // Extra fallback: se por algum motivo common_dir não existe mas runtime_arduino existe,
    // tentamos usar runtime_arduino direto (layout legado onde os arquivos estão em arduino/)
    if (!dir_exists(common_dir) && dir_exists(ctx->runtime_arduino)) {
        // Só troca se runtime_arduino tiver sketch.ino diretamente
        char probe[1024];
        snprintf(probe, sizeof(probe), "%s/sketch.ino", ctx->runtime_arduino);
        if (file_exists(probe)) {
            strncpy(common_dir, ctx->runtime_arduino, sizeof(common_dir) - 1);
            common_dir[sizeof(common_dir) - 1] = 0;
        }
    }

    log_info("Runtime Arduino (common): %s", common_dir);

    if (!require_and_copy(common_dir, "sketch.ino", ctx->sketch_dir)) return 0;

    // Runtime can rename the shim header. Always stage it as ArduinoSwiftShim.h in the sketch.
    {
        const char* const cand[] = {
            "ArduinoSwiftShim.h",
            "ArduinoSwiftShimBase.h",
            "ArduinoSwiftShim.hpp",
            "ArduinoSwiftShimBase.hpp",
        };
        if (!copy_first_existing_as(common_dir, cand, (int)(sizeof(cand)/sizeof(cand[0])),
                                    ctx->sketch_dir, "ArduinoSwiftShim.h")) return 0;
    }

    // Runtime may provide ArduinoSwiftShimBase.cpp; the sketch expects ArduinoSwiftShim.cpp.
    // Accept either name, but always stage as ArduinoSwiftShim.cpp.
    {
        const char* const cand[] = {
            "ArduinoSwiftShim.cpp",
            "ArduinoSwiftShimBase.cpp",
        };
        if (!copy_first_existing_as(common_dir, cand, (int)(sizeof(cand)/sizeof(cand[0])),
                                    ctx->sketch_dir, "ArduinoSwiftShim.cpp")) return 0;
    }

    if (!require_and_copy(common_dir, "Bridge.cpp", ctx->sketch_dir)) return 0;

    // Runtime support may be provided as .c or .cpp (and may be suffixed with Base).
    // Prefer the .c variant when present.
    //
    // We try a few likely locations:
    //   1) common_dir (arduino/commom)
    //   2) runtime_arduino root (legacy layouts)
    //   3) runtime_swift root / common / support
    {
        const char* const cand_c[] = {
            "SwiftRuntimeSupport.c",
            "SwiftRuntimeSupportBase.c",
        };

        const char* const cand_cpp[] = {
            "SwiftRuntimeSupport.cpp",
            "SwiftRuntimeSupportBase.cpp",
            "SwiftRuntimeSupport.cxx",
            "SwiftRuntimeSupportBase.cxx",
        };

        const char* src_dirs[8];
        int src_dir_count = 0;

        // 1) Normal common dir
        if (common_dir[0] && dir_exists(common_dir)) src_dirs[src_dir_count++] = common_dir;

        // 2) runtime_arduino root (older layout)
        if (ctx->runtime_arduino[0] && dir_exists(ctx->runtime_arduino)) src_dirs[src_dir_count++] = ctx->runtime_arduino;

        // 3) runtime_swift root
        if (ctx->runtime_swift[0] && dir_exists(ctx->runtime_swift)) src_dirs[src_dir_count++] = ctx->runtime_swift;

        // 4) runtime_swift/common
        char swift_common_dir[1024];
        snprintf(swift_common_dir, sizeof(swift_common_dir), "%s/common", ctx->runtime_swift);
        if (dir_exists(swift_common_dir)) src_dirs[src_dir_count++] = swift_common_dir;

        // 5) runtime_swift/support
        char swift_support_dir[1024];
        snprintf(swift_support_dir, sizeof(swift_support_dir), "%s/support", ctx->runtime_swift);
        if (dir_exists(swift_support_dir)) src_dirs[src_dir_count++] = swift_support_dir;

        int copied = 0;

        // Prefer C output
        for (int di = 0; di < src_dir_count && !copied; di++) {
            const char* sd = src_dirs[di];
            if (!sd || !sd[0] || !dir_exists(sd)) continue;

            if (copy_first_existing_as(sd, cand_c, (int)(sizeof(cand_c)/sizeof(cand_c[0])),
                                       ctx->sketch_dir, "SwiftRuntimeSupport.c")) {
                copied = 1;
                break;
            }
        }

        // Fallback to C++
        for (int di = 0; di < src_dir_count && !copied; di++) {
            const char* sd = src_dirs[di];
            if (!sd || !sd[0] || !dir_exists(sd)) continue;

            if (copy_first_existing_as(sd, cand_cpp, (int)(sizeof(cand_cpp)/sizeof(cand_cpp[0])),
                                       ctx->sketch_dir, "SwiftRuntimeSupport.cpp")) {
                copied = 1;
                break;
            }
        }

        if (!copied) {
            log_warn("SwiftRuntimeSupport.* not found in runtime folders (continuing without it).\n"
                     "If link fails later, add SwiftRuntimeSupport.c/.cpp under arduino/commom or runtime_swift/support.");
        }
    }

    return 1;
}