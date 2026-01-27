// json_helpers.h
//
// Minimal JSON helpers for parsing simple arrays of strings.
//
// Supported patterns:
// - "lib": ["I2C", "Button"]
// - "arduino_lib": ["SomeArduinoLib", ...]
//
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int parse_json_string_array(const char* json,
                            const char* key,
                            char out_items[][64],
                            int max_items);

#ifdef __cplusplus
} // extern "C"
#endif
