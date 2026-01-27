// step_4_stage_sources_and_libs.h
//
// Build step 4: stage_sources_and_libs
//
// Collects Swift core + libs, stages Arduino-side libs, promotes C/C++ bridges,
// and generates ArduinoSwiftLibs.cpp.
//
// Contract:
// - Returns 1 on success, 0 on failure.
//
#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int cmd_build_step_4_stage_sources_and_libs(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
