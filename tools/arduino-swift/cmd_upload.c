// cmd_upload.c
//
// Firmware upload command for ArduinoSwift.
//
// What this command does:
// - Loads project configuration from ARDUINO_SWIFT_ROOT (default "."):
//     - reads: config.json (expects "board")
//     - reads: boards.json (resolves board -> fqbn)
// - Validates build artifacts exist before uploading:
//     - requires: <root>/build/arduino_build (produced by `arduino-swift build`)
// - Chooses a serial port to upload to:
//     - If environment variable PORT is set, it is used as-is.
//     - Otherwise, it auto-detects a suitable port by parsing `arduino-cli board list`:
//         - First tries JSON output (`--format json`) and searches for entries whose
//           surrounding object matches the selected fqbn (or its base token).
//         - Prefers USB-like ports (usbmodem/usbserial/ttyACM/ttyUSB).
//         - Rejects pseudo-ports such as Bluetooth/Incoming/rfcomm/debug-console.
//     - If no good port is found, it fails with instructions to set PORT explicitly.
// - Executes the upload using Arduino CLI:
//     - arduino-cli upload -p <PORT> --fqbn <FQBN> --input-dir <build/arduino_build> <build/sketch>
//
// Port detection rules (important):
// - Bluetooth / network / “Incoming” ports are ignored to prevent accidental uploads.
// - USB serial ports are preferred because they are the most likely valid targets.
// - If the system reports multiple boards, the matching logic attempts to pick the one
//   associated with the selected fqbn.
//
// Expected environment:
// - arduino-cli must be installed and available in PATH.
// - A successful `arduino-swift build` must have been run beforehand.
//
// Usage examples:
// - Auto-detect port:
//     arduino-swift upload
// - Force a specific port:
//     PORT=/dev/cu.usbmodemXXXX arduino-swift upload

#include "util.h"
#include "jsonlite.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int is_bad_port(const char* p) {
  if (!p || !p[0]) return 1;

  // Avoid Bluetooth/Network/Incoming pseudo-ports
  if (strstr(p, "Bluetooth") || strstr(p, "Incoming") || strstr(p, "rfcomm")) return 1;

  // macOS pseudo ports that appear sometimes
  if (strstr(p, "debug-console") || strstr(p, "debug-console")) return 1;

  return 0;
}

static int is_preferred_usb_port(const char* p) {
  if (!p) return 0;
  return (strstr(p, "usbmodem") || strstr(p, "usbserial") || strstr(p, "ttyACM") || strstr(p, "ttyUSB"));
}

static void fqbn_base_token(const char* fqbn, char* out, size_t cap) {
  // base token = last segment after ':' (e.g. arduino_due_x)
  if (!out || cap == 0) return;
  out[0] = 0;
  if (!fqbn) return;

  const char* last = strrchr(fqbn, ':');
  const char* tok = last ? last + 1 : fqbn;
  strncpy(out, tok, cap - 1);
  out[cap - 1] = 0;
}

static int detect_port_for_fqbn(const char* fqbn, char* out, size_t cap) {
  // Strategy:
  // 1) Parse `arduino-cli board list --format json` heuristically.
  //    For each entry with an address, check if the same object contains the fqbn (or base token).
  //    Prefer USB ports. Never return Bluetooth/debug-console.
  // 2) If JSON doesn't help, parse the human table and prefer usbmodem/usbserial/etc.

  if (!out || cap == 0) return 0;
  out[0] = 0;

  char base[128];
  fqbn_base_token(fqbn, base, sizeof(base));

  char buf[65535];
  int rc = run_cmd_capture("arduino-cli board list --format json 2>/dev/null", buf, sizeof(buf));
  if (rc == 0 && buf[0]) {
    char best[256] = {0};
    int best_is_usb = 0;

    const char* p = buf;
    const size_t buf_len = strlen(buf);

    while ((p = strstr(p, "\"address\"")) != NULL) {
      const char* a = strchr(p, ':');
      if (!a) { p += 9; continue; }
      a++;
      while (*a && (*a==' ' || *a=='\t')) a++;
      if (*a != '"') { p += 9; continue; }
      a++;
      const char* end = strchr(a, '"');
      if (!end) break;

      char addr[256] = {0};
      size_t n = (size_t)(end - a);
      if (n >= sizeof(addr)) n = sizeof(addr) - 1;
      memcpy(addr, a, n);
      addr[n] = 0;

      // Skip bad ports
      if (is_bad_port(addr)) { p = end; continue; }

      // Look in a window around this address for fqbn/base token
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
      else if (base[0] && strstr(window, base)) matches = 1;

      if (matches) {
        int usb = is_preferred_usb_port(addr);

        // Prefer USB match over non-USB match
        if (!best[0] || (usb && !best_is_usb)) {
          strncpy(best, addr, sizeof(best) - 1);
          best_is_usb = usb;

          // If we got a USB match, it's almost certainly the right one.
          // Stop early to avoid picking debug/other later.
          if (usb) break;
        }
      }

      p = end;
    }

    if (best[0]) {
      strncpy(out, best, cap - 1);
      out[cap - 1] = 0;
      return 1;
    }
  }

  // Fallback: parse the human output and pick best USB-like port
  {
    char outbuf[8192];
    if (run_cmd_capture("arduino-cli board list 2>/dev/null", outbuf, sizeof(outbuf)) == 0 && outbuf[0]) {
      const char* lines = outbuf;

      // 1) If fqbn/base token appears on a line, take its first column (port), but avoid bad ports
      const char* hit = NULL;
      if (fqbn && fqbn[0]) hit = strstr(lines, fqbn);
      if (!hit && base[0]) hit = strstr(lines, base);

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

        if (port[0] && !is_bad_port(port)) {
          strncpy(out, port, cap - 1);
          out[cap - 1] = 0;
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

        if (out[0] && !is_bad_port(out)) return 1;
      }
    }
  }

  return 0;
}

int cmd_upload(int argc, char** argv) {
  (void)argc; (void)argv;

  const char* root = getenv("ARDUINO_SWIFT_ROOT");
  if (!root) root = ".";

  char config_path[512], boards_path[512], build_dir[512], sketch_dir[512], ard_build[512];
  snprintf(config_path, sizeof(config_path), "%s/config.json", root);
  snprintf(boards_path, sizeof(boards_path), "%s/boards.json", root);
  snprintf(build_dir, sizeof(build_dir), "%s/build", root);
  snprintf(sketch_dir, sizeof(sketch_dir), "%s/sketch", build_dir);
  snprintf(ard_build, sizeof(ard_build), "%s/arduino_build", build_dir);

  if (!dir_exists(ard_build)) die("Build output not found. Run: arduino-swift build");

  char* cfg = read_file(config_path);
  char* bjs = read_file(boards_path);
  if (!cfg || !bjs) die("Failed to read json");

  char board[128]={0};
  if (!json_get_string(cfg, "board", board, sizeof(board))) die("config.json missing board");

  const char* ob=NULL; const char* oe=NULL;
  if (!boards_get_object_span(bjs, board, &ob, &oe)) die("Invalid board: %s", board);

  char fqbn[256]={0};
  if (!json_get_string_in_span(ob, oe, "fqbn", fqbn, sizeof(fqbn))) die("boards.json missing fqbn");

  const char* env_port = getenv("PORT");
  char port[256]={0};

  if (env_port && env_port[0]) {
    strncpy(port, env_port, sizeof(port)-1);
    port[sizeof(port)-1] = 0;
  } else {
    if (!detect_port_for_fqbn(fqbn, port, sizeof(port))) {
      die("No suitable port detected. Tip: PORT=/dev/cu.usbmodemXXXX arduino-swift upload");
    }
  }

  if (!port[0]) {
    die("No suitable port detected. Tip: PORT=/dev/cu.usbmodemXXXX arduino-swift upload");
  }
  if (is_bad_port(port)) {
    die("Detected an invalid port (Bluetooth/debug-console). Set PORT explicitly, e.g.: PORT=/dev/cu.usbmodemXXXX arduino-swift upload");
  }

  ok("Uploading (FQBN=%s, PORT=%s)", fqbn, port);

  char cmd[2048];
  snprintf(cmd, sizeof(cmd),
    "arduino-cli upload -p \"%s\" --fqbn \"%s\" --input-dir \"%s\" \"%s\"",
    port, fqbn, ard_build, sketch_dir
  );
  if (run_cmd(cmd) != 0) die("Upload failed");

  ok("upload complete");
  free(cfg); free(bjs);
  return 0;
}