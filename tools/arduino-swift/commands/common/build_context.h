// build_context.h
//
// Shared build context for ArduinoSwift CLI commands.
//
// Centralizes:
// - Paths (project/tool/runtime/build dirs)
// - Loaded config/boards JSON
// - Board selection + toolchain fields
// - Parsed lib arrays
//
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct BuildContext {
    char project_root[1024];
    char tool_root[1024];
    char runtime_arduino[1024];
    char runtime_swift[1024];

    char config_path[1024];
    char boards_path[1024];

    char build_dir[1024];
    char sketch_dir[1024];
    char ard_build_dir[1024];

    char logs_dir[1024];
    char last_log_path[1024];

    char* cfg_json;
    char* boards_json;

    char board[128];
    char fqbn[256];
    char core[256];
    char swift_target[128];
    char cpu[128];
    char swiftc[512];

    char user_arduino_lib_dir[1024];

    char swift_libs[64][64];
    int  swift_lib_count;

    char arduino_libs[64][64];
    int  arduino_lib_count;

    char resolved_leafs[64][64];
    int  resolved_leaf_count;

    char swift_obj_path[1024];
    char main_swift_path[1024];

    char swift_args[200000];
} BuildContext;

int  build_ctx_init(BuildContext* ctx);
int  build_ctx_load_json(BuildContext* ctx);
int  build_ctx_select_board_and_parse(BuildContext* ctx);
int  build_ctx_prepare_dirs(BuildContext* ctx);
void build_ctx_destroy(BuildContext* ctx);
void build_ctx_set_step_log(BuildContext* ctx, const char* name);

#ifdef __cplusplus
} // extern "C"
#endif
