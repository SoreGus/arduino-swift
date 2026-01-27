// upload_step_3_detect_port_and_upload.h
//
// Upload step 3: validate build artifacts, detect port, and run arduino-cli upload.
//
// Responsibilities:
// - Ensure build outputs exist:
//     - build/arduino_build (arduino-cli build directory from `arduino-swift build`)
//     - build/sketch        (sketch workspace used during build)
// - Choose a port:
//     - PORT env var wins, if set
//     - else auto-detect using `arduino-cli board list`
// - Execute:
//     arduino-cli upload -p <PORT> --fqbn <FQBN> --input-dir <build/arduino_build> <build/sketch>
//
// Returns:
// - 1 on success
// - 0 on failure
//
#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int upload_step_3_detect_port_and_upload(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
