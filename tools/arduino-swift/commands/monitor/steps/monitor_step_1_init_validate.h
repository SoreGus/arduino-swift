// monitor_step_1_init_validate.h
//
// Step 1 (monitor): Validate host environment for `arduino-swift monitor`.
//

#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int monitor_step_1_init_validate(BuildContext* ctx);

#ifdef __cplusplus
}
#endif
