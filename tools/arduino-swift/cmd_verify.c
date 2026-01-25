#include "util.h"
#include "jsonlite.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void ensure_cmd_exists(const char* cmd) {
  char buf[256];
  snprintf(buf, sizeof(buf), "command -v %s >/dev/null 2>&1", cmd);
  if (run_cmd(buf) != 0) die("Missing dependency: %s", cmd);
  ok("Found %s", cmd);
}

static int supports_embedded_swift(const char* swiftc_path, const char* swift_target) {
  char cmd[1024];
  // same test you usou: -print-target-info + runtimeResourcePath contains /embedded
  // We'll just grep "embedded" in runtimeResourcePath directory existence is hard in pure C without parsing.
  // So: capture runtimeResourcePath and then test "[ -d path/embedded ]"
  snprintf(cmd, sizeof(cmd),
    "%s -print-target-info -target %s 2>/dev/null | "
    "awk -F'\"' '/runtimeResourcePath/ {print $4; exit}'",
    swiftc_path, swift_target);

  char out[1024];
  int rc = run_cmd_capture(cmd, out, sizeof(out));
  if (rc != 0) return 0;

  // trim
  char* nl = strchr(out, '\n'); if (nl) *nl = 0;
  if (!out[0]) return 0;

  char testcmd[1400];
  snprintf(testcmd, sizeof(testcmd), "[ -d \"%s/embedded\" ]", out);
  return run_cmd(testcmd) == 0;
}

int cmd_verify(int argc, char** argv) {
  (void)argc; (void)argv;

  const char* root = getenv("ARDUINO_SWIFT_ROOT");
  if (!root) root = ".";

  char config_path[512], boards_path[512], build_dir[512], env_path[512], swiftc_path_file[512];
  snprintf(config_path, sizeof(config_path), "%s/config.json", root);
  snprintf(boards_path, sizeof(boards_path), "%s/boards.json", root);
  snprintf(build_dir, sizeof(build_dir), "%s/build", root);
  snprintf(env_path, sizeof(env_path), "%s/env.sh", build_dir);
  snprintf(swiftc_path_file, sizeof(swiftc_path_file), "%s/.swiftc_path", build_dir);

  if (!file_exists(config_path)) die("config.json not found");
  if (!file_exists(boards_path)) die("boards.json not found");
  ensure_dir(build_dir);

  ensure_cmd_exists("arduino-cli");
  ensure_cmd_exists("python3");

  // ensure swiftly shims in PATH (same as script)
  {
    const char* home = getenv("HOME");
    if (home) {
      char newpath[2048];
      const char* old = getenv("PATH");
      snprintf(newpath, sizeof(newpath), "%s/.swiftly/bin:%s", home, old ? old : "");
      setenv("PATH", newpath, 1);
    }
  }

  char* cfg = read_file(config_path);
  char* bjs = read_file(boards_path);
  if (!cfg || !bjs) die("Failed to read config/boards json");

  char board[128] = {0};
  if (!json_get_string(cfg, "board", board, sizeof(board))) {
    die("config.json must contain: { \"board\": \"...\" }");
  }

  const char* ob = NULL; const char* oe = NULL;
  if (!boards_get_object_span(bjs, board, &ob, &oe)) {
    die("Invalid board '%s' (not found in boards.json)", board);
  }

  char fqbn[256]={0}, core[256]={0}, swift_target[128]={0};
  char cpu[128]={0};
  if (!json_get_string_in_span(ob, oe, "fqbn", fqbn, sizeof(fqbn))) die("boards.json missing fqbn for board");
  if (!json_get_string_in_span(ob, oe, "core", core, sizeof(core))) die("boards.json missing core for board");
  if (!json_get_string_in_span(ob, oe, "swift_target", swift_target, sizeof(swift_target))) {
    strncpy(swift_target, "armv7-none-none-eabi", sizeof(swift_target)-1);
  }
  if (!json_get_string_in_span(ob, oe, "cpu", cpu, sizeof(cpu))) {
    strncpy(cpu, "cortex-m3", sizeof(cpu)-1);
  }

  ok("board = %s", board);
  ok("fqbn  = %s", fqbn);
  ok("core  = %s", core);

  // update index (ignore failure)
  run_cmd("arduino-cli core update-index || true");

  // ensure core installed
  {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "arduino-cli core list | awk '{print $1}' | grep -qx \"%s\"", core);
    if (run_cmd(cmd) == 0) {
      ok("Core already installed: %s", core);
    } else {
      warn("Core not installed: %s", core);
      if (!prompt_yes_no("Install this core now?", 0)) die("Cannot proceed without core: %s", core);
      snprintf(cmd, sizeof(cmd), "arduino-cli core install \"%s\"", core);
      if (run_cmd(cmd) != 0) die("Failed to install core: %s", core);
      ok("Core installed: %s", core);
    }
  }

  // swiftc detection (same order: env SWIFTC, ~/.swiftly/bin/swiftc, swiftc in PATH)
  char swiftc[512] = {0};
  const char* env_swiftc = getenv("SWIFTC");
  if (env_swiftc && env_swiftc[0]) strncpy(swiftc, env_swiftc, sizeof(swiftc)-1);

  if (!swiftc[0]) {
    const char* home = getenv("HOME");
    if (home) {
      char cand[512];
      snprintf(cand, sizeof(cand), "%s/.swiftly/bin/swiftc", home);
      if (file_exists(cand)) strncpy(swiftc, cand, sizeof(swiftc)-1);
    }
  }

  if (!swiftc[0]) {
    // resolve swiftc from PATH
    char out[512];
    if (run_cmd_capture("command -v swiftc 2>/dev/null", out, sizeof(out)) == 0) {
      char* nl = strchr(out, '\n'); if (nl) *nl = 0;
      if (out[0]) strncpy(swiftc, out, sizeof(swiftc)-1);
    }
  }

  if (!swiftc[0]) {
    warn("swiftc not found. Install swiftly + main-snapshot, or set SWIFTC=/path/to/swiftc");
    die("No Embedded Swift toolchain found");
  }

  // verify embedded swift support
  if (!supports_embedded_swift(swiftc, swift_target)) {
    die("This swiftc does NOT support Embedded Swift for target '%s'\nSet SWIFTC or run swiftly main-snapshot.", swift_target);
  }

  ok("Embedded Swift swiftc found: %s", swiftc);

  // write build/.swiftc_path + build/env.sh
  if (!write_file(swiftc_path_file, swiftc)) die("Failed writing %s", swiftc_path_file);

  char env_sh[1200];
  snprintf(env_sh, sizeof(env_sh),
    "# Auto-generated by arduino-swift verify\n"
    "export SWIFTC=\"%s\"\n"
    "export ARDUINO_BOARD=\"%s\"\n"
    "export ARDUINO_FQBN=\"%s\"\n"
    "export ARDUINO_CORE=\"%s\"\n"
    "export SWIFT_TARGET=\"%s\"\n"
    "export SWIFT_CPU=\"%s\"\n",
    swiftc, board, fqbn, core, swift_target, cpu
  );
  if (!write_file(env_path, env_sh)) die("Failed writing %s", env_path);

  ok("Wrote: %s", env_path);
  ok("verify complete.");
  free(cfg); free(bjs);
  return 0;
}