// step_4_stage_sources_and_libs.c
#include "step_4_stage_sources_and_libs.h"

#include "common/build_log.h"
#include "common/fs_helpers.h"
#include "util.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static int str_ieq(const char* a, const char* b) {
    if (!a || !b) return 0;
    while (*a && *b) {
        unsigned char ca = (unsigned char)*a;
        unsigned char cb = (unsigned char)*b;
        if (ca >= 'A' && ca <= 'Z') ca = (unsigned char)(ca - 'A' + 'a');
        if (cb >= 'A' && cb <= 'Z') cb = (unsigned char)(cb - 'A' + 'a');
        if (ca != cb) return 0;
        ++a; ++b;
    }
    return (*a == 0 && *b == 0) ? 1 : 0;
}

static void append_swift_list_as_args(const char* newline_list, char* out_args, size_t out_cap) {
    if (!newline_list || !newline_list[0]) return;

    char* tmp = (char*)malloc(strlen(newline_list) + 1);
    if (!tmp) die("OOM");
    strcpy(tmp, newline_list);

    char* p = tmp;
    while (*p) {
        char* e = strchr(p, '\n');
        if (e) *e = 0;

        if (p[0]) {
            size_t need = strlen(out_args) + strlen(p) + 4 + 2;
            if (need >= out_cap) die("Too many Swift files (args buffer overflow)");
            strcat(out_args, "\"");
            strcat(out_args, p);
            strcat(out_args, "\" ");
        }

        if (!e) break;
        p = e + 1;
    }

    free(tmp);
}

static int resolve_swift_lib_dir(const char* runtime_swift,
                                const char* libName,
                                char* out_dir, size_t out_dir_cap,
                                char* out_leaf, size_t out_leaf_cap) {
    char libs_root[1024];
    if (!path_join(libs_root, sizeof(libs_root), runtime_swift, "libs")) return 0;
    return fs_resolve_dir_case_insensitive(libs_root, libName, out_dir, out_dir_cap, out_leaf, out_leaf_cap);
}

static int resolve_arduino_lib_dir(const char* runtime_arduino,
                                  const char* libName,
                                  char* out_dir, size_t out_dir_cap,
                                  char* out_leaf, size_t out_leaf_cap) {
    char libs_root[1024];
    if (!path_join(libs_root, sizeof(libs_root), runtime_arduino, "libs")) return 0;
    return fs_resolve_dir_case_insensitive(libs_root, libName, out_dir, out_dir_cap, out_leaf, out_leaf_cap);
}

// ---------- tiny helpers ----------

static const char* path_basename(const char* p) {
    const char* s = p ? strrchr(p, '/') : NULL;
    return s ? (s + 1) : (p ? p : "");
}

static int cp_file_force(const char* src, const char* dst) {
    char cmd[4096];
    // -f overwrite, keep simple (tool runs on mac/linux)
    snprintf(cmd, sizeof(cmd), "cp -f \"%s\" \"%s\"", src, dst);
    return run_cmd(cmd) == 0;
}

static void mkdir_p(const char* dir) {
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", dir);
    (void)run_cmd(cmd);
}

static void write_text_file(const char* path, const char* content) {
    FILE* f = fopen(path, "wb");
    if (!f) die("Failed to write %s", path);
    fwrite(content, 1, strlen(content), f);
    fclose(f);
}

// List helpers (newline separated paths)
static int list_c_cpp_files(const char* dir, char* out, size_t out_cap) {
    if (!dir || !dir[0]) return 0;
    out[0] = 0;
    return fs_find_list(dir,
        "-type f \\( -name \"*.c\" -o -name \"*.cpp\" -o -name \"*.cc\" -o -name \"*.cxx\" \\)",
        out, out_cap
    );
}

static int list_headers(const char* dir, char* out, size_t out_cap) {
    if (!dir || !dir[0]) return 0;
    out[0] = 0;
    // include .h + .hpp
    if (!fs_find_list(dir, "-type f \\( -name \"*.h\" -o -name \"*.hpp\" -o -name \"*.hh\" -o -name \"*.hxx\" \\)", out, out_cap))
        return 0;
    return 1;
}

/*
  Key rule (no manifest, no Arduino lib detection dependency):
  - Bridge sources (.c/.cpp) MUST be compiled & linked -> put them in sketch root.
  - Headers included by those sources MUST be reachable -> generate shim headers in sketch root
    that forward to libraries/<Lib>/src/<Header>.
*/
static void generate_shim_headers_for_lib(const char* sketch_dir, const char* leaf) {
    char src_dir[1024];
    snprintf(src_dir, sizeof(src_dir), "%s/libraries/%s/src", sketch_dir, leaf);
    if (!dir_exists(src_dir)) return;

    char hdrs[65535];
    hdrs[0] = 0;
    if (!list_headers(src_dir, hdrs, sizeof(hdrs)) || !hdrs[0]) return;

    char* tmp = (char*)malloc(strlen(hdrs) + 1);
    if (!tmp) die("OOM");
    strcpy(tmp, hdrs);

    char* p = tmp;
    while (*p) {
        char* e = strchr(p, '\n');
        if (e) *e = 0;

        if (p[0]) {
            const char* base = path_basename(p);

            char shim_path[1024];
            snprintf(shim_path, sizeof(shim_path), "%s/%s", sketch_dir, base);

            // If exists, don't overwrite. If collision happens, warn (user must resolve).
            if (file_exists(shim_path)) {
                log_warn("Shim header collision: %s already exists (skipping)", base);
            } else {
                char rel[1024];
                snprintf(rel, sizeof(rel), "libraries/%s/src/%s", leaf, base);

                char content[1400];
                snprintf(content, sizeof(content),
                    "// Auto-generated by ArduinoSwift\n"
                    "#pragma once\n"
                    "#include \"%s\"\n",
                    rel
                );
                write_text_file(shim_path, content);
                log_info("Shim header: %s -> %s", base, rel);
            }
        }

        if (!e) break;
        p = e + 1;
    }

    free(tmp);
}

static void promote_bridge_sources_to_sketch_root(const char* sketch_dir, const char* leaf) {
    char src_dir[1024];
    snprintf(src_dir, sizeof(src_dir), "%s/libraries/%s/src", sketch_dir, leaf);
    if (!dir_exists(src_dir)) return;

    char list[65535];
    list[0] = 0;
    if (!list_c_cpp_files(src_dir, list, sizeof(list)) || !list[0]) return;

    char* tmp = (char*)malloc(strlen(list) + 1);
    if (!tmp) die("OOM");
    strcpy(tmp, list);

    char* p = tmp;
    while (*p) {
        char* e = strchr(p, '\n');
        if (e) *e = 0;

        if (p[0]) {
            const char* base = path_basename(p);

            char dst[1024];
            // ensure unique name in sketch root
            snprintf(dst, sizeof(dst), "%s/__asw_%s__%s", sketch_dir, leaf, base);

            if (!cp_file_force(p, dst)) {
                log_warn("Failed promoting source: %s -> %s", p, dst);
            } else {
                log_info("Promoted: %s -> %s", base, path_basename(dst));
            }
        }

        if (!e) break;
        p = e + 1;
    }

    free(tmp);
}

/*
  Ensure library 1.5 layout for staged libs:
    libraries/<Name>/src/*
  This keeps things organized and also helps if the user later wants pure Arduino-lib behavior.
*/
static void normalize_arduino_lib_layout(const char* lib_dir) {
    if (!lib_dir || !lib_dir[0]) return;
    if (!dir_exists(lib_dir)) return;

    char src_dir[1024];
    snprintf(src_dir, sizeof(src_dir), "%s/src", lib_dir);

    if (dir_exists(src_dir)) return;

    // if root has sources/headers, move into src
    char probe_cmd[2048];
    snprintf(probe_cmd, sizeof(probe_cmd),
             "cd \"%s\" && find . -maxdepth 1 -type f \\( -name \"*.c\" -o -name \"*.cpp\" -o -name \"*.cc\" -o -name \"*.cxx\" -o -name \"*.h\" -o -name \"*.hpp\" -o -name \"*.hh\" -o -name \"*.hxx\" \\) | grep -q .",
             lib_dir);
    if (run_cmd(probe_cmd) != 0) return;

    char cmd[8192];
    snprintf(cmd, sizeof(cmd),
      "set -e; "
      "cd \"%s\"; "
      "mkdir -p \"src\"; "
      "for f in *.c *.cpp *.cc *.cxx *.h *.hpp *.hh *.hxx; do "
      "  [ -f \"$f\" ] && mv \"$f\" \"src/\" || true; "
      "done; "
      "true",
      lib_dir
    );
    (void)run_cmd(cmd);
}

static void ensure_arduino_library_properties(const char* lib_dir, const char* lib_name) {
    if (!lib_dir || !lib_dir[0]) return;
    if (!lib_name || !lib_name[0]) return;
    if (!dir_exists(lib_dir)) return;

    char props_path[1024];
    snprintf(props_path, sizeof(props_path), "%s/library.properties", lib_dir);

    if (file_exists(props_path)) return;

    FILE* f = fopen(props_path, "wb");
    if (!f) return;

    fprintf(f,
        "name=%s\n"
        "version=0.0.0\n"
        "author=ArduinoSwift\n"
        "maintainer=ArduinoSwift\n"
        "sentence=Auto-generated metadata for staged ArduinoSwift bridge sources.\n"
        "paragraph=Generated by ArduinoSwift to keep staged libs in Arduino 1.5 format.\n"
        "category=Other\n"
        "url=\n"
        "architectures=*\n",
        lib_name
    );
    fclose(f);
}

static void debug_dump_sketch_tree(const char* sketch_dir) {
    char cmd[4096];
    snprintf(cmd, sizeof(cmd),
      "echo \"--- sketch tree (maxdepth=4) ---\"; "
      "cd \"%s\" && "
      "find . -maxdepth 4 -type f | sed 's|^\\./||' | sort; "
      "echo \"--- end sketch tree ---\"",
      sketch_dir
    );
    run_cmd(cmd);
}

int cmd_build_step_4_stage_sources_and_libs(BuildContext* ctx) {
    if (!ctx) return 0;

    ctx->swift_args[0] = 0;

    // --------------------------------------------------
    // 1) Core Swift files
    // --------------------------------------------------
    char core_list[65535];
    {
        char root[1024];
        snprintf(root, sizeof(root), "%s/core", ctx->runtime_swift);
        if (!fs_find_list(root, "-type f -name \"*.swift\"", core_list, sizeof(core_list))) {
            log_error("Failed listing Swift core sources");
            return 0;
        }
    }
    if (!core_list[0]) {
        log_error("No Swift core sources found in: %s/core", ctx->runtime_swift);
        return 0;
    }
    append_swift_list_as_args(core_list, ctx->swift_args, sizeof(ctx->swift_args));

    if (ctx->swift_lib_count > 0) log_info("Including %d Swift lib(s)", ctx->swift_lib_count);
    else                         log_info("No Swift libs specified -> core only");

    // --------------------------------------------------
    // 2) Swift libs + optional Arduino libs
    //    Staging rule (professional):
    //      - keep libs under sketch/libraries/<Lib>/src
    //      - ALSO promote bridge .c/.cpp into sketch root to guarantee compile/link
    //      - generate shim headers in sketch root to satisfy #include "X.h"
    // --------------------------------------------------
    for (int i = 0; i < ctx->swift_lib_count; i++) {
        const char* libname = ctx->swift_libs[i];
        if (!libname || !libname[0]) continue;

        char swift_libdir[1024];
        char swift_leaf[64] = {0};
        int found_swift = 0;

        // tool swift libs
        if (resolve_swift_lib_dir(ctx->runtime_swift, libname, swift_libdir, sizeof(swift_libdir), swift_leaf, sizeof(swift_leaf))) {
            found_swift = 1;
        }

        // project-local swift libs
        if (!found_swift) {
            char project_swift_root[1024];
            if (path_join(project_swift_root, sizeof(project_swift_root), ctx->project_root, "libs") && dir_exists(project_swift_root)) {
                if (fs_resolve_dir_case_insensitive(project_swift_root, libname, swift_libdir, sizeof(swift_libdir), swift_leaf, sizeof(swift_leaf))) {
                    found_swift = 1;
                    log_info("Using project-local Swift lib: %s (%s)", swift_leaf, swift_libdir);
                }
            }
        }

        if (!found_swift) {
            log_error("Swift lib not found: %s", libname);
            return 0;
        }

        // add swift sources to swiftc args
        char lib_list[65535];
        lib_list[0] = 0;
        if (!fs_find_list(swift_libdir, "-type f -name \"*.swift\"", lib_list, sizeof(lib_list)) || !lib_list[0]) {
            log_error("No Swift files found in lib dir: %s", swift_libdir);
            return 0;
        }

        const char* leaf = (swift_leaf[0] ? swift_leaf : libname);
        log_info("Adding Swift lib: %s", leaf);
        append_swift_list_as_args(lib_list, ctx->swift_args, sizeof(ctx->swift_args));

        // ---- Stage Swift C/C++ bridges into sketch/libraries/<leaf> ----
        {
            char dst_libdir[1024];
            snprintf(dst_libdir, sizeof(dst_libdir), "%s/libraries/%s", ctx->sketch_dir, leaf);
            mkdir_p(dst_libdir);

            log_info("Staging Swift bridge sources for lib: %s", leaf);

            if (!fs_copy_c_cpp_h_recursive(swift_libdir, dst_libdir)) {
                log_error("Failed to copy Swift lib C/C++ from %s", swift_libdir);
                return 0;
            }

            normalize_arduino_lib_layout(dst_libdir);
            ensure_arduino_library_properties(dst_libdir, leaf);

            // Guarantee compile/link:
            generate_shim_headers_for_lib(ctx->sketch_dir, leaf);
            promote_bridge_sources_to_sketch_root(ctx->sketch_dir, leaf);
        }

        // ---- Stage optional Arduino-side lib shipped with tool ----
        {
            char arduino_libdir[1024];
            char arduino_leaf[64] = {0};

            if (resolve_arduino_lib_dir(ctx->runtime_arduino, libname, arduino_libdir, sizeof(arduino_libdir), arduino_leaf, sizeof(arduino_leaf))) {
                const char* aleaf = (arduino_leaf[0] ? arduino_leaf : libname);

                char dst_libdir[1024];
                snprintf(dst_libdir, sizeof(dst_libdir), "%s/libraries/%s", ctx->sketch_dir, aleaf);
                mkdir_p(dst_libdir);

                log_info("Copying Arduino lib: %s", aleaf);
                if (!fs_copy_dir_recursive(arduino_libdir, dst_libdir)) {
                    log_error("Failed to copy Arduino lib dir: %s", arduino_libdir);
                    return 0;
                }

                normalize_arduino_lib_layout(dst_libdir);
                ensure_arduino_library_properties(dst_libdir, aleaf);

                // same guarantee rule:
                generate_shim_headers_for_lib(ctx->sketch_dir, aleaf);
                promote_bridge_sources_to_sketch_root(ctx->sketch_dir, aleaf);
            } else {
                log_info("Swift-only lib (no Arduino side): %s", libname);
            }
        }
    }

    // --------------------------------------------------
    // 3) User Arduino libs — do NOT stage/copy (avoid duplicate compilation)
    // --------------------------------------------------
    if (ctx->user_arduino_lib_dir[0] && ctx->arduino_lib_count > 0) {
        log_info("User Arduino libs requested: %d (sketchbook=%s)", ctx->arduino_lib_count, ctx->user_arduino_lib_dir);

        for (int i = 0; i < ctx->arduino_lib_count; i++) {
            const char* libname = ctx->arduino_libs[i];
            if (!libname || !libname[0]) continue;

            char ext_libdir[1024];
            char ext_leaf[64] = {0};

            if (!fs_resolve_dir_case_insensitive(ctx->user_arduino_lib_dir, libname, ext_libdir, sizeof(ext_libdir), ext_leaf, sizeof(ext_leaf))) {
                log_warn("User Arduino lib not found in sketchbook: %s (skipping)", libname);
                continue;
            }

            const char* leaf = (ext_leaf[0] ? ext_leaf : libname);
            log_info("Using user Arduino lib (sketchbook): %s (%s)", leaf, ext_libdir);
        }
    }

    debug_dump_sketch_tree(ctx->sketch_dir);
    return 1;
}