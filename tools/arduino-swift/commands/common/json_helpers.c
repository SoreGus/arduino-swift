// json_helpers.c
// Minimal JSON scanners for ArduinoSwift tools.
// Prefixed with asw_ to avoid collisions with jsonlite.c symbols.

#include "json_helpers.h"

#include <string.h>
#include <ctype.h>
#include <stdint.h>

static const char* skip_ws(const char* p, const char* end) {
    while (p && p < end && *p && isspace((unsigned char)*p)) p++;
    return p;
}

static const char* find_quoted_key(const char* begin, const char* end, const char* key) {
    // Find: "key"
    size_t klen = strlen(key);
    if (!begin || !end || end <= begin || !key || !key[0]) return NULL;

    const char* p = begin;
    while (p < end) {
        const void* hit = memchr(p, '"', (size_t)(end - p));
        if (!hit) return NULL;
        p = (const char*)hit + 1; // after quote

        if (p + klen < end && strncmp(p, key, klen) == 0 && p[klen] == '"') {
            return p - 1; // opening quote
        }
        p++;
    }
    return NULL;
}

static const char* find_colon_after_key(const char* key_quote, const char* end) {
    if (!key_quote) return NULL;

    // Find closing quote of key
    const char* p = key_quote + 1;
    const void* hit = memchr(p, '"', (size_t)(end - p));
    if (!hit) return NULL;
    p = (const char*)hit + 1;

    // Skip to ':'
    p = skip_ws(p, end);
    while (p && p < end && *p && *p != ':') p++;
    if (!p || p >= end || *p != ':') return NULL;
    return p;
}

static int parse_json_string_value(const char* p, const char* end, char* out, size_t cap) {
    if (!out || cap == 0) return 0;
    out[0] = 0;

    p = skip_ws(p, end);
    if (!p || p >= end || *p != '"') return 0;
    p++; // inside string

    size_t w = 0;
    int esc = 0;

    while (p < end && *p) {
        char c = *p++;
        if (!esc) {
            if (c == '\\') { esc = 1; continue; }
            if (c == '"') break;
            if (w + 1 < cap) out[w++] = c;
        } else {
            esc = 0;
            char mapped = c;
            if (c == 'n') mapped = '\n';
            else if (c == 'r') mapped = '\r';
            else if (c == 't') mapped = '\t';
            else if (c == '"') mapped = '"';
            else if (c == '\\') mapped = '\\';
            if (w + 1 < cap) out[w++] = mapped;
        }
    }

    if (w < cap) out[w] = 0;
    return 1;
}

static int object_span_from(const char* p, const char* end, const char** ob, const char** oe) {
    if (!ob || !oe) return 0;
    *ob = NULL; *oe = NULL;

    p = skip_ws(p, end);
    if (!p || p >= end || *p != '{') return 0;

    const char* start = p;
    int depth = 0;
    int in_str = 0;
    char prev = 0;

    while (p < end && *p) {
        char c = *p++;
        if (c == '"' && prev != '\\') in_str = !in_str;

        if (!in_str) {
            if (c == '{') depth++;
            else if (c == '}') {
                depth--;
                if (depth == 0) {
                    *ob = start;
                    *oe = p; // one past
                    return 1;
                }
            }
        }
        prev = c;
    }
    return 0;
}

// --- public API (prefixed) ---

int asw_json_get_string_in_span(const char* begin, const char* end, const char* key, char* out, size_t cap) {
    if (!begin || !end || end <= begin || !key || !out || cap == 0) return 0;

    const char* kq = find_quoted_key(begin, end, key);
    if (!kq) return 0;

    const char* colon = find_colon_after_key(kq, end);
    if (!colon) return 0;

    return parse_json_string_value(colon + 1, end, out, cap);
}

int asw_json_get_string(const char* json, const char* key, char* out, size_t cap) {
    if (!json) return 0;
    return asw_json_get_string_in_span(json, json + strlen(json), key, out, cap);
}

int asw_json_get_object_span_in_span(const char* begin, const char* end, const char* key, const char** ob, const char** oe) {
    if (!begin || !end || end <= begin || !key || !ob || !oe) return 0;

    const char* kq = find_quoted_key(begin, end, key);
    if (!kq) return 0;

    const char* colon = find_colon_after_key(kq, end);
    if (!colon) return 0;

    return object_span_from(colon + 1, end, ob, oe);
}

int asw_json_get_object_span(const char* json, const char* key, const char** ob, const char** oe) {
    if (!json) return 0;
    return asw_json_get_object_span_in_span(json, json + strlen(json), key, ob, oe);
}

int asw_boards_get_object_span(const char* boards_json, const char* board_name, const char** ob, const char** oe) {
    // boards_json: { "GigaR1": { ... }, "Due": { ... } }
    return asw_json_get_object_span(boards_json, board_name, ob, oe);
}

// ---- array parsing ----

static const char* parse_string_token(const char* p, const char* end, char* out, size_t cap, int* ok) {
    *ok = 0;
    if (!p || p >= end || *p != '"') return p;

    p++;
    size_t w = 0;
    int esc = 0;

    while (p < end && *p) {
        char c = *p++;
        if (!esc) {
            if (c == '\\') { esc = 1; continue; }
            if (c == '"') break;
            if (w + 1 < cap) out[w++] = c;
        } else {
            esc = 0;
            char mapped = c;
            if (c == 'n') mapped = '\n';
            else if (c == 'r') mapped = '\r';
            else if (c == 't') mapped = '\t';
            else if (c == '"') mapped = '"';
            else if (c == '\\') mapped = '\\';
            if (w + 1 < cap) out[w++] = mapped;
        }
    }

    if (w < cap) out[w] = 0;
    *ok = 1;
    return p;
}

int asw_parse_json_string_array(const char* json, const char* key, char out[][64], int max_count) {
    if (!json || !key || !out || max_count <= 0) return 0;
    for (int i = 0; i < max_count; i++) out[i][0] = 0;

    const char* begin = json;
    const char* end = json + strlen(json);

    const char* kq = find_quoted_key(begin, end, key);
    if (!kq) return 0;

    const char* colon = find_colon_after_key(kq, end);
    if (!colon) return 0;

    const char* p = skip_ws(colon + 1, end);
    if (!p || p >= end || *p != '[') return 0;
    p++;

    int count = 0;

    for (;;) {
        p = skip_ws(p, end);
        if (!p || p >= end) break;

        if (*p == ']') { p++; break; }
        if (*p == ',') { p++; continue; }

        if (*p == '"') {
            int ok = 0;
            char tmp[64];
            tmp[0] = 0;

            p = parse_string_token(p, end, tmp, sizeof(tmp), &ok);
            if (ok && count < max_count) {
                strncpy(out[count], tmp, 63);
                out[count][63] = 0;
                count++;
            }
            continue;
        }

        p++;
    }

    return count;
}