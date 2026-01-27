// port_detect.c
//
// Serial port auto-detection helpers for ArduinoSwift commands.
//
// See port_detect.h for behavior and constraints.

#include "port_detect.h"

#include "util.h"          // run_cmd, run_cmd_capture
#include <string.h>        // strstr, strrchr, strlen, memcpy
#include <stdio.h>         // snprintf

int port_is_bad(const char* p) {
    if (!p || !p[0]) return 1;

    // Avoid Bluetooth/Network/Incoming pseudo-ports
    if (strstr(p, "Bluetooth") || strstr(p, "Incoming") || strstr(p, "rfcomm")) return 1;

    // Some macOS pseudo ports
    if (strstr(p, "debug-console")) return 1;

    return 0;
}

int port_is_preferred_usb(const char* p) {
    if (!p) return 0;
    return (strstr(p, "usbmodem") || strstr(p, "usbserial") || strstr(p, "ttyACM") || strstr(p, "ttyUSB"));
}

void fqbn_base_token(const char* fqbn, char* out, size_t cap) {
    if (!out || cap == 0) return;
    out[0] = 0;
    if (!fqbn) return;

    const char* last = strrchr(fqbn, ':');
    const char* tok = last ? last + 1 : fqbn;
    snprintf(out, cap, "%s", tok);
}

static int detect_port_from_json_board_list(const char* fqbn, const char* base, char* out, size_t cap) {
    // Parse `arduino-cli board list --format json` heuristically.
    // For each "address", check if a nearby window contains fqbn or base token.

    char buf[65535];
    if (run_cmd_capture("arduino-cli board list --format json 2>/dev/null", buf, sizeof(buf)) != 0) return 0;
    if (!buf[0]) return 0;

    const size_t buf_len = strlen(buf);
    const char* p = buf;

    char best[256] = {0};
    int best_is_usb = 0;

    while ((p = strstr(p, "\"address\"")) != NULL) {
        const char* a = strchr(p, ':');
        if (!a) { p += 9; continue; }
        a++;
        while (*a && (*a == ' ' || *a == '\t')) a++;
        if (*a != '"') { p += 9; continue; }
        a++;
        const char* end = strchr(a, '"');
        if (!end) break;

        char addr[256] = {0};
        size_t n = (size_t)(end - a);
        if (n >= sizeof(addr)) n = sizeof(addr) - 1;
        memcpy(addr, a, n);
        addr[n] = 0;

        if (port_is_bad(addr)) { p = end; continue; }

        // Window around this address field (cheap "same object" heuristic)
        const char* win_start = p;
        if (win_start > buf + 600) win_start = p - 600;

        const char* win_end = p + 1200;
        if (win_end > buf + buf_len) win_end = buf + buf_len;

        char window[2000];
        size_t wn = (size_t)(win_end - win_start);
        if (wn >= sizeof(window)) wn = sizeof(window) - 1;
        memcpy(window, win_start, wn);
        window[wn] = 0;

        int matches = 0;
        if (fqbn && fqbn[0] && strstr(window, fqbn)) matches = 1;
        else if (base && base[0] && strstr(window, base)) matches = 1;

        if (matches) {
            const int usb = port_is_preferred_usb(addr);
            if (!best[0] || (usb && !best_is_usb)) {
                snprintf(best, sizeof(best), "%s", addr);
                best_is_usb = usb;
                if (usb) break; // a good USB match is typically "the one"
            }
        }

        p = end;
    }

    if (!best[0]) return 0;
    snprintf(out, cap, "%s", best);
    return 1;
}

static int detect_port_from_human_board_list(const char* fqbn, const char* base, char* out, size_t cap) {
    // Fallback: parse `arduino-cli board list` table output.
    char lines[8192];
    if (run_cmd_capture("arduino-cli board list 2>/dev/null", lines, sizeof(lines)) != 0) return 0;
    if (!lines[0]) return 0;

    // 1) If fqbn/base appears on some line, take first column (port)
    const char* hit = NULL;
    if (fqbn && fqbn[0]) hit = strstr(lines, fqbn);
    if (!hit && base && base[0]) hit = strstr(lines, base);

    if (hit) {
        const char* ls = hit;
        while (ls > lines && ls[-1] != '\n') ls--;

        char port[256] = {0};
        size_t i = 0;
        while (ls[i] && ls[i] != ' ' && ls[i] != '\t' && ls[i] != '\n' && i + 1 < sizeof(port)) {
            port[i] = ls[i];
            i++;
        }
        port[i] = 0;

        if (port[0] && !port_is_bad(port)) {
            snprintf(out, cap, "%s", port);
            return 1;
        }
    }

    // 2) Prefer common USB serial substrings
    const char* k = strstr(lines, "usbmodem");
    if (!k) k = strstr(lines, "usbserial");
    if (!k) k = strstr(lines, "ttyACM");
    if (!k) k = strstr(lines, "ttyUSB");

    if (k) {
        const char* s = k;
        while (s > lines && s[-1] != ' ' && s[-1] != '\n') s--;

        size_t n = 0;
        while (s[n] && s[n] != ' ' && s[n] != '\n' && n + 1 < cap) { out[n] = s[n]; n++; }
        out[n] = 0;

        if (out[0] && !port_is_bad(out)) return 1;
    }

    return 0;
}

int detect_port_for_fqbn(const char* fqbn, char* out, size_t cap) {
    if (!out || cap == 0) return 0;
    out[0] = 0;

    char base[128] = {0};
    fqbn_base_token(fqbn, base, sizeof(base));

    if (detect_port_from_json_board_list(fqbn, base, out, cap)) return 1;
    if (detect_port_from_human_board_list(fqbn, base, out, cap)) return 1;
    return 0;
}
