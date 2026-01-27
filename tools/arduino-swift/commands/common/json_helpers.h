// json_helpers.h
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

// NOTE: Prefix asw_ to avoid collisions with jsonlite.c

int asw_json_get_string(const char* json, const char* key, char* out, size_t cap);
int asw_json_get_string_in_span(const char* begin, const char* end, const char* key, char* out, size_t cap);

int asw_json_get_object_span(const char* json, const char* key, const char** ob, const char** oe);
int asw_json_get_object_span_in_span(const char* begin, const char* end, const char* key, const char** ob, const char** oe);

int asw_boards_get_object_span(const char* boards_json, const char* board_name, const char** ob, const char** oe);

int asw_parse_json_string_array(const char* json, const char* key, char out[][64], int max_count);

#ifdef __cplusplus
} // extern "C"
#endif