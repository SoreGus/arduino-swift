// fs_helpers.c
#include "fs_helpers.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int fs_mkdir_p(const char* path) {
    if (!path || !path[0]) return 0;
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", path);
    return system(cmd) == 0 ? 1 : 0;
}

int fs_rm_rf(const char* path) {
    if (!path || !path[0]) return 0;
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "rm -rf \"%s\"", path);
    return system(cmd) == 0 ? 1 : 0;
}

int fs_copy_file(const char* src, const char* dst) {
    if (!src || !dst) return 0;
    char cmd[4096];
    snprintf(cmd, sizeof(cmd), "cp \"%s\" \"%s\"", src, dst);
    return system(cmd) == 0 ? 1 : 0;
}

int fs_copy_dir_recursive(const char* src_dir, const char* dst_dir) {
    if (!src_dir || !dst_dir) return 0;
    (void)fs_mkdir_p(dst_dir);
    char cmd[8192];
    snprintf(cmd, sizeof(cmd), "cp -R \"%s/.\" \"%s/\"", src_dir, dst_dir);
    return system(cmd) == 0 ? 1 : 0;
}

int fs_copy_c_cpp_h_recursive(const char* src_dir, const char* dst_dir) {
    if (!src_dir || !dst_dir) return 0;
    (void)fs_mkdir_p(dst_dir);

    char cmd[8192];
    snprintf(cmd, sizeof(cmd),
        "cd \"%s\" && "
        "find . -type f \\( -name \"*.c\" -o -name \"*.cpp\" -o -name \"*.h\" \\) -print "
        "| sed 's|^\\./||' "
        "| while read f; do "
        "  mkdir -p \"%s/$(dirname \"$f\")\"; "
        "  cp \"%s/$f\" \"%s/$f\"; "
        "done",
        src_dir, dst_dir, src_dir, dst_dir
    );
    return system(cmd) == 0 ? 1 : 0;
}

int fs_find_list(const char* root_dir, const char* find_expr, char* out, size_t out_cap) {
    if (!out || out_cap == 0) return 0;
    out[0] = 0;
    if (!root_dir || !root_dir[0]) return 0;
    if (!find_expr || !find_expr[0]) return 0;

    char cmd[8192];
    snprintf(cmd, sizeof(cmd), "find \"%s\" %s -print 2>/dev/null | sort", root_dir, find_expr);

    FILE* pipe = popen(cmd, "r");
    if (!pipe) return 0;

    size_t used = 0;
    char line[2048];
    while (fgets(line, sizeof(line), pipe)) {
        size_t n = strlen(line);
        if (used + n + 1 >= out_cap) break;
        memcpy(out + used, line, n);
        used += n;
        out[used] = 0;
    }
    (void)pclose(pipe);
    return 1;
}

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

int fs_resolve_dir_case_insensitive(const char* base,
                                   const char* leaf,
                                   char* out_full, size_t out_full_cap,
                                   char* out_leaf, size_t out_leaf_cap) {
    if (!base || !base[0]) return 0;
    if (!leaf || !leaf[0]) return 0;
    if (!out_full || out_full_cap == 0) return 0;

    char cmd[4096];
    snprintf(cmd, sizeof(cmd), "ls -1 \"%s\" 2>/dev/null", base);

    FILE* pipe = popen(cmd, "r");
    if (!pipe) return 0;

    char line[1024];
    while (fgets(line, sizeof(line), pipe)) {
        char* nl = strchr(line, '\n');
        if (nl) *nl = 0;
        if (!line[0]) continue;

        if (str_ieq(line, leaf)) {
            if (out_leaf && out_leaf_cap > 0) {
                strncpy(out_leaf, line, out_leaf_cap - 1);
                out_leaf[out_leaf_cap - 1] = 0;
            }
            snprintf(out_full, out_full_cap, "%s/%s", base, line);
            pclose(pipe);
            return 1;
        }
    }

    pclose(pipe);
    return 0;
}
