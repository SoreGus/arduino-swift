#include "jsonlite.h"
#include <string.h>
#include <ctype.h>

static const char* skip_ws(const char* p) {
  while (*p && isspace((unsigned char)*p)) p++;
  return p;
}

static const char* find_quoted_key(const char* json, const char* key) {
  // find: "key"
  size_t klen = strlen(key);
  for (const char* p = json; *p; p++) {
    if (*p != '"') continue;
    if (strncmp(p+1, key, klen) == 0 && p[1+klen] == '"') return p;
  }
  return NULL;
}

static int extract_quoted_string(const char* p, char* out, size_t out_cap) {
  // p points to opening quote
  if (*p != '"') return 0;
  p++;
  size_t n = 0;
  while (*p && *p != '"') {
    if (*p == '\\' && p[1]) { // naive unescape
      p++;
    }
    if (n + 1 < out_cap) out[n++] = *p;
    p++;
  }
  if (*p != '"') return 0;
  if (out_cap) out[n] = 0;
  return 1;
}

int json_get_string(const char* json, const char* key, char* out, size_t out_cap) {
  const char* k = find_quoted_key(json, key);
  if (!k) return 0;
  const char* p = k + 1 + strlen(key) + 1; // after "key"
  p = skip_ws(p);
  if (*p != ':') return 0;
  p++;
  p = skip_ws(p);
  if (*p != '"') return 0;
  return extract_quoted_string(p, out, out_cap);
}

int boards_get_object_span(const char* boards_json, const char* board_name,
                           const char** obj_begin, const char** obj_end) {
  // find: "board_name" : { ... }
  const char* k = find_quoted_key(boards_json, board_name);
  if (!k) return 0;
  const char* p = k + 1 + strlen(board_name) + 1;
  p = skip_ws(p);
  if (*p != ':') return 0;
  p++;
  p = skip_ws(p);
  if (*p != '{') return 0;

  const char* begin = p;
  int depth = 0;
  while (*p) {
    if (*p == '{') depth++;
    else if (*p == '}') {
      depth--;
      if (depth == 0) {
        *obj_begin = begin;
        *obj_end = p + 1;
        return 1;
      }
    }
    p++;
  }
  return 0;
}

int json_get_string_in_span(const char* begin, const char* end,
                            const char* key, char* out, size_t out_cap) {
  // search only inside [begin, end)
  size_t span_len = (size_t)(end - begin);
  // make a temp slice (safe, small enough; boards.json objects are small)
  char tmp[8192];
  if (span_len >= sizeof(tmp)) return 0;
  memcpy(tmp, begin, span_len);
  tmp[span_len] = 0;
  return json_get_string(tmp, key, out, out_cap);
}