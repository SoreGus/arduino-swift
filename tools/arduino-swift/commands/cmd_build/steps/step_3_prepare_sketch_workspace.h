// step_3_prepare_sketch_workspace.h
//
// Build step 3: prepare_sketch_workspace
//
// Cleans build outputs, recreates directories,
// and copies Arduino sketch template + shim sources.
//
// Contract:
// - Returns 1 on success, 0 on failure.
//
#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int cmd_build_step_3_prepare_sketch_workspace(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
