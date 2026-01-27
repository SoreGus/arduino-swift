// json_helpers.c
#include "json_helpers.h"

#include <string.h>
#include <stdio.h>

static const char* skip_ws(const char* p) {
    while (*p && (*p==' ' || *p=='\t' || *p=='\r' || *p=='\n')) p++;
    return p;
}

int parse_json_string_array(const char* json,
                            const char* key,
                            char out_items[][64],
                            int max_items) {
    if (!json || !key || !key[0] || !out_items || max_items <= 0) return 0;

    char needle[128];
    snprintf(needle, sizeof(needle), "\"%s\"", key);

    const char* k = strstr(json, needle);
    if (!k) return 0;

    k = strchr(k, ':');
    if (!k) return 0;
    k++;
    k = skip_ws(k);

    if (*k != '[') return 0;
    k++;

    int count = 0;
    for (;;) {
        k = skip_ws(k);
        if (*k == ']') return count;
        if (*k == ',') { k++; continue; }

        if (*k != '"') {
            while (*k && *k != ',' && *k != ']') k++;
            continue;
        }

        k++;
        char tmp[64] = {0};
        size_t n = 0;

        while (*k && *k != '"' && n + 1 < sizeof(tmp)) {
            if (*k == '\\' && k[1]) k++;
            tmp[n++] = *k++;
        }
        tmp[n] = 0;

        if (*k == '"') k++;

        if (tmp[0] && count < max_items) {
            strncpy(out_items[count], tmp, 63);
            out_items[count][63] = 0;
            count++;
        }

        while (*k && *k != ',' && *k != ']') k++;
        if (*k == ',') k++;
    }
}
