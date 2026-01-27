// step_4_swift_toolchain_check.h
//
// Step 4 (verify): validate Embedded Swift toolchain supports the selected swift_target.
//
// Responsibilities
// ----------------
// - Ensures swiftc exists (ctx->swiftc is prepared by build_ctx_init):
//     - SWIFTC env var, build/.swiftc_path, or PATH fallback
// - Validates that swiftc supports Embedded Swift for ctx->swift_target:
//     - runs `swiftc -print-target-info -target <swift_target>`
//     - extracts runtimeResourcePath
//     - checks that <runtimeResourcePath>/embedded exists
//
// Contract:
// - Returns 1 on success, 0 on failure.
//

#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int verify_step_4_swift_toolchain_check(BuildContext* ctx);

#ifdef __cplusplus
} // extern "C"
#endif
