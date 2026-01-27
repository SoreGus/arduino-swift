// fs_helpers.h
//
// Filesystem helpers shared across ArduinoSwift CLI commands.
//
// Notes:
// - Uses shell tools (mkdir/cp/rm/find/ls) on macOS/Linux.
// - If you later want Windows support, centralize it here.
//
#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int fs_mkdir_p(const char* path);
int fs_rm_rf(const char* path);
int fs_copy_file(const char* src, const char* dst);
int fs_copy_dir_recursive(const char* src_dir, const char* dst_dir);
int fs_copy_c_cpp_h_recursive(const char* src_dir, const char* dst_dir);
int fs_find_list(const char* root_dir, const char* find_expr, char* out, size_t out_cap);

int fs_resolve_dir_case_insensitive(const char* base,
                                   const char* leaf,
                                   char* out_full, size_t out_full_cap,
                                   char* out_leaf, size_t out_leaf_cap);

#ifdef __cplusplus
} // extern "C"
#endif
