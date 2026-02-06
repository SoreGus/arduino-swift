#pragma once
#include <stddef.h>

// Super simples: busca por "key" : "value" em texto JSON.
// Para boards.json: busca primeiro o objeto do board:  "<board>" : { ... }
// e depois busca keys dentro daquele trecho.

int json_get_string(const char* json, const char* key, char* out, size_t out_cap);

// boards.json helpers
int boards_get_object_span(const char* boards_json, const char* board_name,
                           const char** obj_begin, const char** obj_end);

int json_get_string_in_span(const char* begin, const char* end,
                            const char* key, char* out, size_t out_cap);