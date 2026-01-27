// monitor_step_3_open_monitor.h
//
// Step 3 (monitor): Choose PORT + BAUD and open `arduino-cli monitor`.
//

#pragma once

#include "common/build_context.h"

#ifdef __cplusplus
extern "C" {
#endif

int monitor_step_3_open_monitor(BuildContext* ctx);

#ifdef __cplusplus
}
#endif
