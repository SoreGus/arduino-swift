// upload_step_2_read_config_select_board.c
//
// Upload step 2: load config.json + boards.json and resolve the selected board.
//
// Responsibilities:
// - Load JSON into BuildContext (config + boards).
// - Resolve the selected board from config.json ("board") using boards.json.
// - Ensure ctx->fqbn is populated (used by later upload steps).
//
// Notes:
// - BuildContext fields may evolve; this step only relies on fields known to exist:
//   ctx->config_path, ctx->boards_path, ctx->fqbn.

#include "upload/steps/upload_step_2_read_config_select_board.h"

#include "common/build_context.h"
#include "common/build_log.h"

#include <string.h> // strchr, memcpy
#include <stdio.h>  // snprintf

// Derive Arduino core from fqbn as "<vendor>:<platform>"
// Examples:
// - "arduino:sam:due" -> "arduino:sam"
// - "arduino:renesas_uno:uno_r4_minima" -> "arduino:renesas_uno"
static int fqbn_to_core(const char* fqbn, char* out, size_t cap) {
    if (!out || cap == 0) return 0;
    out[0] = 0;
    if (!fqbn || !fqbn[0]) return 0;

    const char* first = strchr(fqbn, ':');
    if (!first) return 0;
    const char* second = strchr(first + 1, ':');
    if (!second) return 0;

    size_t n = (size_t)(second - fqbn);
    if (n >= cap) n = cap - 1;

    memcpy(out, fqbn, n);
    out[n] = 0;
    return out[0] ? 1 : 0;
}

int upload_step_2_read_config_select_board(BuildContext* ctx) {
    if (!ctx) {
        log_error("Internal error: BuildContext is NULL");
        return 0;
    }

    if (!build_ctx_load_json(ctx)) {
        log_error("Failed to read config.json / boards.json");
        log_info("Expected:");
        log_info("  - %s", ctx->config_path);
        log_info("  - %s", ctx->boards_path);
        return 0;
    }

    if (!build_ctx_select_board_and_parse(ctx)) {
        log_error("Failed to resolve selected board from config.json");
        log_info("Tip: check your config.json contains a valid \"board\" key that exists in boards.json.");
        return 0;
    }

    if (!ctx->fqbn[0]) {
        log_error("Internal error: selected board did not populate FQBN.");
        return 0;
    }

    log_info("FQBN: %s", ctx->fqbn);

    // Optional helpful info (derived from fqbn)
    char core[256];
    if (fqbn_to_core(ctx->fqbn, core, sizeof(core))) {
        log_info("Core: %s", core);
    }

    return 1;
}
