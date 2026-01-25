// cmd_build.c
#include "util.h"
#include "jsonlite.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static void copy_file(const char* src, const char* dst) {
  char cmd[1024];
  snprintf(cmd, sizeof(cmd), "cp \"%s\" \"%s\"", src, dst);
  if (run_cmd(cmd) != 0) die("Failed to copy %s -> %s", src, dst);
}

static void require_and_copy(const char* src_dir, const char* name, const char* dst_dir) {
  char src[1024], dst[1024];
  snprintf(src, sizeof(src), "%s/%s", src_dir, name);
  snprintf(dst, sizeof(dst), "%s/%s", dst_dir, name);
  if (!file_exists(src)) die("Missing required file: %s", src);
  copy_file(src, dst);
  ok("Using %s", name);
}

static void trim_nl(char* s) {
  if (!s) return;
  char* p = strchr(s, '\n');
  if (p) *p = 0;
}

// -----------------------------
// helpers for lib array parsing
// -----------------------------

static const char* skip_ws(const char* p) {
  while (*p && (*p==' ' || *p=='\t' || *p=='\r' || *p=='\n')) p++;
  return p;
}

static int str_ieq(const char* a, const char* b) {
  while (*a && *b) {
    char ca = (char)tolower((unsigned char)*a);
    char cb = (char)tolower((unsigned char)*b);
    if (ca != cb) return 0;
    a++; b++;
  }
  return (*a == 0 && *b == 0);
}

// parse config.json "lib": ["I2C","Button"] into libs[count][64]
static int parse_lib_array(const char* json, char libs[][64], int max) {
  if (!json) return 0;

  const char* k = strstr(json, "\"lib\"");
  if (!k) return 0;

  k = strchr(k, ':');
  if (!k) return 0;
  k++;
  k = skip_ws(k);

  if (*k != '[') return 0;
  k++; // after [

  int count = 0;
  for (;;) {
    k = skip_ws(k);
    if (*k == ']') { // end
      return count;
    }

    if (*k == ',') { k++; continue; }

    if (*k != '"') {
      // not a string, skip token until comma or ]
      while (*k && *k != ',' && *k != ']') k++;
      continue;
    }

    // string
    k++; // after opening quote
    char tmp[64] = {0};
    size_t n = 0;

    while (*k && *k != '"' && n + 1 < sizeof(tmp)) {
      // minimal escape handling for \"
      if (*k == '\\' && k[1]) {
        k++;
      }
      tmp[n++] = *k++;
    }
    tmp[n] = 0;

    if (*k == '"') k++; // closing quote

    if (tmp[0] && count < max) {
      strncpy(libs[count], tmp, 63);
      libs[count][63] = 0;
      count++;
    }

    // advance to next item
    while (*k && *k != ',' && *k != ']') k++;
    if (*k == ',') k++;
  }
}

// Find the actual directory name inside runtime_swift/libs/ that matches libName (case-insensitive).
// Returns 1 and writes resolved path into out if found.
static int resolve_lib_dir(const char* runtime_swift, const char* libName, char* out, size_t cap) {
  // list immediate children of runtime_swift/libs
  char libs_root[1024];
  if (!path_join(libs_root, sizeof(libs_root), runtime_swift, "libs")) return 0;
  if (!dir_exists(libs_root)) return 0;

  char cmd[2048];
  // mac/linux: list directories only
  snprintf(cmd, sizeof(cmd), "ls -1 \"%s\" 2>/dev/null", libs_root);

  char listing[65535];
  if (run_cmd_capture(cmd, listing, sizeof(listing)) != 0) return 0;
  if (!listing[0]) return 0;

  char* p = listing;
  while (*p) {
    char* e = strchr(p, '\n');
    if (e) *e = 0;

    if (p[0]) {
      // build candidate dir
      char cand[1024];
      if (path_join(cand, sizeof(cand), libs_root, p) && dir_exists(cand)) {
        if (str_ieq(p, libName)) {
          strncpy(out, cand, cap - 1);
          out[cap - 1] = 0;
          return 1;
        }
      }
    }

    if (!e) break;
    p = e + 1;
  }

  return 0;
}

// Append a newline-separated file list to a quoted-args string buffer.
static void append_swift_list_as_args(const char* newline_list, char* out_args, size_t out_cap) {
  if (!newline_list || !newline_list[0]) return;

  // copy to temp buffer to mutate (split lines)
  char* tmp = (char*)malloc(strlen(newline_list) + 1);
  if (!tmp) die("OOM");
  strcpy(tmp, newline_list);

  char* p = tmp;
  while (*p) {
    char* e = strchr(p, '\n');
    if (e) *e = 0;

    if (p[0]) {
      size_t need = strlen(out_args) + strlen(p) + 4 + 2;
      if (need >= out_cap) die("Too many swift files (args buffer overflow)");
      strcat(out_args, "\"");
      strcat(out_args, p);
      strcat(out_args, "\" ");
    }

    if (!e) break;
    p = e + 1;
  }

  free(tmp);
}

int cmd_build(int argc, char** argv) {
  (void)argc; (void)argv;

  // -----------------------------
  // Project root (where config.json lives)
  // -----------------------------
  char project_root[1024] = {0};
  const char* env_root = getenv("ARDUINO_SWIFT_ROOT");
  if (env_root && env_root[0]) {
    strncpy(project_root, env_root, sizeof(project_root)-1);
  } else {
    if (!cwd_dir(project_root, sizeof(project_root))) {
      strncpy(project_root, ".", sizeof(project_root)-1);
    }
  }

  // -----------------------------
  // Tool runtime root (where arduino/ and swift/ live)
  // -----------------------------
  const char* tool_root = exe_dir();

  char runtime_arduino[1024], runtime_swift[1024];
  if (!path_join(runtime_arduino, sizeof(runtime_arduino), tool_root, "arduino"))
    die("Path too long (runtime arduino)");
  if (!path_join(runtime_swift, sizeof(runtime_swift), tool_root, "swift"))
    die("Path too long (runtime swift)");

  if (!dir_exists(runtime_arduino)) die("Missing runtime arduino dir: %s", runtime_arduino);
  if (!dir_exists(runtime_swift)) die("Missing runtime swift dir: %s", runtime_swift);

  // -----------------------------
  // Project files
  // -----------------------------
  char config_path[1024], boards_path[1024];
  char build_dir[1024], sketch_dir[1024], ard_build[1024], ard_cache[1024];

  snprintf(config_path, sizeof(config_path), "%s/config.json", project_root);
  snprintf(boards_path, sizeof(boards_path), "%s/boards.json", project_root);

  snprintf(build_dir, sizeof(build_dir), "%s/build", project_root);
  snprintf(sketch_dir, sizeof(sketch_dir), "%s/sketch", build_dir);
  snprintf(ard_build, sizeof(ard_build), "%s/arduino_build", build_dir);
  snprintf(ard_cache, sizeof(ard_cache), "%s/arduino_cache", build_dir);

  if (!file_exists(config_path)) die("config.json not found at: %s", config_path);
  if (!file_exists(boards_path)) die("boards.json not found at: %s", boards_path);

  // deps
  if (run_cmd("command -v arduino-cli >/dev/null 2>&1") != 0) die("Missing dependency: arduino-cli");
  if (run_cmd("command -v python3 >/dev/null 2>&1") != 0) die("Missing dependency: python3");

  // ensure PATH has swiftly
  {
    const char* home = getenv("HOME");
    if (home) {
      char newpath[2048];
      const char* old = getenv("PATH");
      snprintf(newpath, sizeof(newpath), "%s/.swiftly/bin:%s", home, old ? old : "");
      setenv("PATH", newpath, 1);
    }
  }

  // clean + mkdir
  {
    char cmd[2048];
    snprintf(cmd, sizeof(cmd),
      "rm -rf \"%s\" \"%s\" && mkdir -p \"%s\" \"%s\" \"%s\" \"%s\"",
      sketch_dir, ard_build, build_dir, sketch_dir, ard_build, ard_cache);
    if (run_cmd(cmd) != 0) die("Failed to prepare build dirs");
  }

  char* cfg = read_file(config_path);
  char* bjs = read_file(boards_path);
  if (!cfg || !bjs) die("Failed to read config/boards json");

  char board[128]={0};
  if (!json_get_string(cfg, "board", board, sizeof(board)))
    die("config.json missing board");

  const char* ob=NULL; const char* oe=NULL;
  if (!boards_get_object_span(bjs, board, &ob, &oe))
    die("Invalid board: %s", board);

  char fqbn[256]={0}, swift_target[128]={0}, cpu[128]={0};
  if (!json_get_string_in_span(ob, oe, "fqbn", fqbn, sizeof(fqbn)))
    die("boards.json missing fqbn for board: %s", board);

  if (!json_get_string_in_span(ob, oe, "swift_target", swift_target, sizeof(swift_target)))
    strncpy(swift_target, "armv7-none-none-eabi", sizeof(swift_target)-1);

  if (!json_get_string_in_span(ob, oe, "cpu", cpu, sizeof(cpu)))
    strncpy(cpu, "cortex-m3", sizeof(cpu)-1);

  // swiftc from build/.swiftc_path or env SWIFTC (project-local)
  char swiftc[512]={0};
  {
    char pfile[1024];
    snprintf(pfile, sizeof(pfile), "%s/.swiftc_path", build_dir);
    if (file_exists(pfile)) {
      char* s = read_file(pfile);
      if (s) {
        trim_nl(s);
        strncpy(swiftc, s, sizeof(swiftc)-1);
        free(s);
      }
    }
    const char* env = getenv("SWIFTC");
    if (env && env[0]) strncpy(swiftc, env, sizeof(swiftc)-1);
  }
  if (!swiftc[0]) strncpy(swiftc, "swiftc", sizeof(swiftc)-1);

  // -----------------------------
  // Copy REAL sketch sources from tool runtime -> project build/sketch
  // -----------------------------
  ok("Preparing Arduino sketch...");
  require_and_copy(runtime_arduino, "sketch.ino", sketch_dir);
  require_and_copy(runtime_arduino, "ArduinoSwiftShim.h", sketch_dir);
  require_and_copy(runtime_arduino, "ArduinoSwiftShim.cpp", sketch_dir);
  require_and_copy(runtime_arduino, "Bridge.cpp", sketch_dir);
  require_and_copy(runtime_arduino, "SwiftRuntimeSupport.c", sketch_dir);

  // -----------------------------
  // Compile Swift: runtime_swift/core/*.swift + selected libs + PROJECT main.swift
  // -----------------------------
  char obj[1024];
  snprintf(obj, sizeof(obj), "%s/ArduinoSwiftApp.o", sketch_dir);

  // 1) core swift files
  char find_core_cmd[2048];
  snprintf(find_core_cmd, sizeof(find_core_cmd),
    "find \"%s/core\" -type f -name \"*.swift\" -print | sort",
    runtime_swift
  );

  char core_list[65535];
  if (run_cmd_capture(find_core_cmd, core_list, sizeof(core_list)) != 0)
    die("Failed listing swift core sources");
  if (!core_list[0])
    die("No Swift core sources found in: %s/core", runtime_swift);

  // Build quoted args string (core first)
  char swift_args[160000];
  swift_args[0] = 0;
  append_swift_list_as_args(core_list, swift_args, sizeof(swift_args));

  // 2) parse config.json libs and append their swift files
  char libs[64][64];
  int lib_count = parse_lib_array(cfg, libs, 64);

  if (lib_count > 0) {
    ok("Including %d Swift lib(s) from config.json", lib_count);
  } else {
    ok("No libs specified in config.json (\"lib\": [...]) -> using core only");
  }

  for (int i = 0; i < lib_count; i++) {
    const char* libname = libs[i];
    if (!libname || !libname[0]) continue;

    char libdir[1024];
    if (!resolve_lib_dir(runtime_swift, libname, libdir, sizeof(libdir))) {
      die("Swift lib not found: %s (expected in %s/libs/<LIB>/)", libname, runtime_swift);
    }

    char find_lib_cmd[2048];
    snprintf(find_lib_cmd, sizeof(find_lib_cmd),
      "find \"%s\" -type f -name \"*.swift\" -print | sort",
      libdir
    );

    char lib_list[65535];
    if (run_cmd_capture(find_lib_cmd, lib_list, sizeof(lib_list)) != 0)
      die("Failed listing swift lib sources: %s", libdir);
    if (!lib_list[0])
      die("No Swift files found in lib dir: %s", libdir);

    ok("Adding Swift lib: %s (%s)", libname, libdir);
    append_swift_list_as_args(lib_list, swift_args, sizeof(swift_args));
  }

  // 3) project main.swift MUST exist in project root
  char main_swift[1024];
  snprintf(main_swift, sizeof(main_swift), "%s/main.swift", project_root);
  if (!file_exists(main_swift))
    die("Missing main.swift at project root: %s", main_swift);

  // add it last
  {
    size_t need = strlen(swift_args) + strlen(main_swift) + 4 + 2;
    if (need >= sizeof(swift_args)) die("Args buffer overflow adding main.swift");
    strcat(swift_args, "\"");
    strcat(swift_args, main_swift);
    strcat(swift_args, "\" ");
  }

  // swiftc cmd (matches your compile.sh flags)
  char swiftc_cmd[200000];
  snprintf(swiftc_cmd, sizeof(swiftc_cmd),
    "%s "
    "-target %s -O -wmo -parse-as-library "
    "-Xfrontend -enable-experimental-feature -Xfrontend Embedded "
    "-Xfrontend -target-cpu -Xfrontend %s "
    "-Xfrontend -disable-stack-protector "
    "-Xcc -mcpu=%s -Xcc -mthumb -Xcc -ffreestanding -Xcc -fno-builtin "
    "-Xcc -fdata-sections -Xcc -ffunction-sections -Xcc -fno-short-enums "
    "%s "
    "-c -o \"%s\"",
    swiftc,
    swift_target,
    cpu,
    cpu,
    swift_args,
    obj
  );

  ok("Compiling Swift -> %s", obj);
  if (run_cmd(swiftc_cmd) != 0) die("Swift compile failed");

  // -----------------------------
  // arduino-cli compile (inject obj)
  // -----------------------------
  char cli_cmd[8192];
  snprintf(cli_cmd, sizeof(cli_cmd),
    "arduino-cli compile --clean "
    "--fqbn \"%s\" "
    "--build-path \"%s\" "
    "--build-cache-path \"%s\" "
    "--build-property \"compiler.c.extra_flags=-fno-short-enums\" "
    "--build-property \"compiler.cpp.extra_flags=-fno-short-enums\" "
    "--build-property \"compiler.c.elf.extra_flags=%s\" "
    "\"%s\"",
    fqbn,
    ard_build,
    ard_cache,
    obj,
    sketch_dir
  );

  ok("Building with Arduino CLI (FQBN=%s)", fqbn);
  if (run_cmd(cli_cmd) != 0) die("arduino-cli compile failed");

  ok("build complete");
  ok("Artifacts: %s", ard_build);

  free(cfg);
  free(bjs);
  return 0;
}