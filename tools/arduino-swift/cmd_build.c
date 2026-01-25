// cmd_build.c
// - Compiles Swift (core + selected libs) into a single .o
// - Copies sketch + C/C++ shim files into build/sketch
// - Copies matching Arduino C/C++ libraries for the selected Swift libs
//   from arduino/libs/<LIB>/ into build/sketch/libraries/<LIB>/
// - Generates an "ArduinoSwiftLibs.c" inside the sketch that force-compiles the selected
//   Arduino libs by including their implementation units (best-effort: <LIB>.c then <LIB>.cpp).
// - Calls arduino-cli compile while injecting the Swift .o
//
// Why ArduinoSwiftLibs.c?
// Arduino CLI's "library discovery" is heuristic. When you only #include <LIB.h>,
// the CLI may still decide not to compile your sketch-local library, depending on paths,
// include style, header location, and casing. Including the .c/.cpp directly guarantees
// the objects are compiled and linked, fixing "undefined reference to arduino_i2c_*".
//
// Conventions:
// - config.json may contain: "lib": ["I2C", "BUTTON"]
// - Swift libs live at:   <tool>/swift/libs/<LIB>/     (case-insensitive resolved)
// - Arduino libs live at: <tool>/arduino/libs/<LIB>/   (case-insensitive resolved)
// - Each Arduino lib directory may contain .c/.cpp/.h and nested folders.
// - Preferred Arduino lib entrypoint file is: <LIB>.c (or <LIB>.cpp) inside its folder.
//   Example: arduino/libs/I2C/I2C.c -> copied to build/sketch/libraries/I2C/I2C.c
// - Swift core must not duplicate typealias/decls that also exist in libs.
//   (that is fixed in Swift code, not here)

#include "util.h"
#include "jsonlite.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// -----------------------------
// Filesystem helpers
// -----------------------------

static void copy_file(const char* src, const char* dst) {
  char cmd[2048];
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
// Helpers for lib array parsing
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

// Parse config.json: "lib": ["I2C","Button"] into libs[count][64]
static int parse_lib_array(const char* json, char libs[][64], int max) {
  if (!json) return 0;

  const char* k = strstr(json, "\"lib\"");
  if (!k) return 0;

  k = strchr(k, ':');
  if (!k) return 0;
  k++;
  k = skip_ws(k);

  if (*k != '[') return 0;
  k++; // after '['

  int count = 0;
  for (;;) {
    k = skip_ws(k);
    if (*k == ']') {
      return count;
    }

    if (*k == ',') { k++; continue; }

    if (*k != '"') {
      while (*k && *k != ',' && *k != ']') k++;
      continue;
    }

    k++; // after opening quote
    char tmp[64] = {0};
    size_t n = 0;

    while (*k && *k != '"' && n + 1 < sizeof(tmp)) {
      if (*k == '\\' && k[1]) {
        k++;
      }
      tmp[n++] = *k++;
    }
    tmp[n] = 0;

    if (*k == '"') k++;

    if (tmp[0] && count < max) {
      strncpy(libs[count], tmp, 63);
      libs[count][63] = 0;
      count++;
    }

    while (*k && *k != ',' && *k != ']') k++;
    if (*k == ',') k++;
  }
}

// -----------------------------
// Lib directory resolvers (Swift + Arduino)
// -----------------------------

// Resolve actual directory name under <runtime_swift>/libs matching libName (case-insensitive).
// Writes:
// - out_dir: full path to resolved dir
// - out_leaf: resolved leaf folder name (actual casing)
static int resolve_swift_lib_dir(const char* runtime_swift,
                                const char* libName,
                                char* out_dir, size_t out_dir_cap,
                                char* out_leaf, size_t out_leaf_cap) {
  char libs_root[1024];
  if (!path_join(libs_root, sizeof(libs_root), runtime_swift, "libs")) return 0;
  if (!dir_exists(libs_root)) return 0;

  char cmd[2048];
  snprintf(cmd, sizeof(cmd), "ls -1 \"%s\" 2>/dev/null", libs_root);

  char listing[65535];
  if (run_cmd_capture(cmd, listing, sizeof(listing)) != 0) return 0;
  if (!listing[0]) return 0;

  char* p = listing;
  while (*p) {
    char* e = strchr(p, '\n');
    if (e) *e = 0;

    if (p[0]) {
      char cand[1024];
      if (path_join(cand, sizeof(cand), libs_root, p) && dir_exists(cand)) {
        if (str_ieq(p, libName)) {
          strncpy(out_dir, cand, out_dir_cap - 1);
          out_dir[out_dir_cap - 1] = 0;

          if (out_leaf && out_leaf_cap) {
            strncpy(out_leaf, p, out_leaf_cap - 1);
            out_leaf[out_leaf_cap - 1] = 0;
          }
          return 1;
        }
      }
    }

    if (!e) break;
    p = e + 1;
  }

  return 0;
}

// Resolve actual directory name under <runtime_arduino>/libs matching libName (case-insensitive).
static int resolve_arduino_lib_dir(const char* runtime_arduino,
                                  const char* libName,
                                  char* out_dir, size_t out_dir_cap,
                                  char* out_leaf, size_t out_leaf_cap) {
  char libs_root[1024];
  if (!path_join(libs_root, sizeof(libs_root), runtime_arduino, "libs")) return 0;
  if (!dir_exists(libs_root)) return 0;

  char cmd[2048];
  snprintf(cmd, sizeof(cmd), "ls -1 \"%s\" 2>/dev/null", libs_root);

  char listing[65535];
  if (run_cmd_capture(cmd, listing, sizeof(listing)) != 0) return 0;
  if (!listing[0]) return 0;

  char* p = listing;
  while (*p) {
    char* e = strchr(p, '\n');
    if (e) *e = 0;

    if (p[0]) {
      char cand[1024];
      if (path_join(cand, sizeof(cand), libs_root, p) && dir_exists(cand)) {
        if (str_ieq(p, libName)) {
          strncpy(out_dir, cand, out_dir_cap - 1);
          out_dir[out_dir_cap - 1] = 0;

          if (out_leaf && out_leaf_cap) {
            strncpy(out_leaf, p, out_leaf_cap - 1);
            out_leaf[out_leaf_cap - 1] = 0;
          }
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

  char* tmp = (char*)malloc(strlen(newline_list) + 1);
  if (!tmp) die("OOM");
  strcpy(tmp, newline_list);

  char* p = tmp;
  while (*p) {
    char* e = strchr(p, '\n');
    if (e) *e = 0;

    if (p[0]) {
      size_t need = strlen(out_args) + strlen(p) + 4 + 2;
      if (need >= out_cap) die("Too many Swift files (args buffer overflow)");
      strcat(out_args, "\"");
      strcat(out_args, p);
      strcat(out_args, "\" ");
    }

    if (!e) break;
    p = e + 1;
  }

  free(tmp);
}

// Copy an Arduino lib directory recursively into build/sketch/libraries/<LIB>/
// macOS/Linux: cp -R "<src>/.\" "<dst>/"
static void copy_arduino_lib_recursive(const char* src_lib_dir, const char* dst_lib_dir) {
  {
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", dst_lib_dir);
    if (run_cmd(cmd) != 0) die("Failed to mkdir: %s", dst_lib_dir);
  }

  {
    char cmd[4096];
    snprintf(cmd, sizeof(cmd), "cp -R \"%s/.\" \"%s/\"", src_lib_dir, dst_lib_dir);
    if (run_cmd(cmd) != 0) die("Failed to copy Arduino lib dir: %s -> %s", src_lib_dir, dst_lib_dir);
  }
}

// Return 1 if a file exists in <dir>/<leaf>.<ext>
static int lib_has_entry_file(const char* lib_dir, const char* leaf, const char* ext) {
  char p[1024];
  snprintf(p, sizeof(p), "%s/%s.%s", lib_dir, leaf, ext);
  return file_exists(p) ? 1 : 0;
}

static void write_lib_includer_cpp(const char* sketch_dir,
                                  char resolved_names[][64],
                                  int count) {
  char path[1024];
  snprintf(path, sizeof(path), "%s/ArduinoSwiftLibs.cpp", sketch_dir);

  FILE* f = fopen(path, "wb");
  if (!f) die("Failed to write %s", path);

  fprintf(f,
    "// ArduinoSwiftLibs.cpp (auto-generated)\n"
    "// Deterministic force-compilation of Arduino libs\n\n"
    "#include <Arduino.h>\n\n"
  );

  for (int i = 0; i < count; i++) {
    const char* leaf = resolved_names[i];
    if (!leaf || !leaf[0]) continue;

    fprintf(f, "// ---- %s ----\n", leaf);

    // List all .c/.cpp files under sketch/libraries/<leaf>/ (recursive)
    char cmd[4096];
    snprintf(cmd, sizeof(cmd),
      "cd \"%s\" && find \"libraries/%s\" -type f \\( -name \"*.c\" -o -name \"*.cpp\" \\) -print | sed 's|^\\./||' | sort",
      sketch_dir, leaf
    );

    char listing[65535];
    listing[0] = 0;

    if (run_cmd_capture(cmd, listing, sizeof(listing)) != 0 || !listing[0]) {
      // OK: some libs are header-only (or only expose symbols via the core/shim).
      // Keep build going; we just don't force-include anything for this lib.
      fprintf(f,
        "// (ArduinoSwift) lib %s: no .c/.cpp compile units found under libraries/%s (header-only or empty)\n\n",
        leaf, leaf
      );
      continue;
    }

    // Emit #include for every found unit (relative path inside sketch_dir)
    char* tmp = (char*)malloc(strlen(listing) + 1);
    if (!tmp) die("OOM");
    strcpy(tmp, listing);

    char* p = tmp;
    while (*p) {
      char* e = strchr(p, '\n');
      if (e) *e = 0;

      if (p[0]) {
        // Safety: don't include the generator file itself if it appears.
        if (strstr(p, "ArduinoSwiftLibs.cpp") == NULL) {
          fprintf(f, "#include \"%s\"\n", p);
        }
      }

      if (!e) break;
      p = e + 1;
    }

    free(tmp);
    fprintf(f, "\n");
  }

  fprintf(f, "void __arduino_swift_force_link_libs(void) {}\n");
  fclose(f);
}

// Print a compact debug tree of the sketch dir (helps diagnose missing files quickly).
static void debug_dump_sketch_tree(const char* sketch_dir) {
  char cmd[4096];
  snprintf(cmd, sizeof(cmd),
    "echo \"--- sketch tree ---\"; "
    "cd \"%s\" && "
    "find . -maxdepth 3 -type f | sed 's|^\\./||' | sort; "
    "echo \"--- end sketch tree ---\"",
    sketch_dir
  );
  run_cmd(cmd); // best-effort; do not fail build on debug
}

// -----------------------------
// cmd_build
// -----------------------------

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
  // Project files/dirs
  // -----------------------------
  char config_path[1024], boards_path[1024];
  char build_dir[1024], sketch_dir[1024], ard_build[1024];

  snprintf(config_path, sizeof(config_path), "%s/config.json", project_root);
  snprintf(boards_path, sizeof(boards_path), "%s/boards.json", project_root);

  snprintf(build_dir, sizeof(build_dir), "%s/build", project_root);
  snprintf(sketch_dir, sizeof(sketch_dir), "%s/sketch", build_dir);
  snprintf(ard_build, sizeof(ard_build), "%s/arduino_build", build_dir);

  if (!file_exists(config_path)) die("config.json not found at: %s", config_path);
  if (!file_exists(boards_path)) die("boards.json not found at: %s", boards_path);

  // Dependencies
  if (run_cmd("command -v arduino-cli >/dev/null 2>&1") != 0) die("Missing dependency: arduino-cli");
  if (run_cmd("command -v python3 >/dev/null 2>&1") != 0) die("Missing dependency: python3");

  // Ensure PATH has swiftly
  {
    const char* home = getenv("HOME");
    if (home) {
      char newpath[2048];
      const char* old = getenv("PATH");
      snprintf(newpath, sizeof(newpath), "%s/.swiftly/bin:%s", home, old ? old : "");
      setenv("PATH", newpath, 1);
    }
  }

  // Clean previous outputs
  {
    char cmd[4096];
    snprintf(cmd, sizeof(cmd), "rm -rf \"%s\" \"%s\"", sketch_dir, ard_build);
    if (run_cmd(cmd) != 0) die("Failed to clean build dirs");
  }

  // Recreate directories
  {
    char cmd[4096];
    snprintf(cmd, sizeof(cmd),
      "mkdir -p \"%s\" \"%s\" \"%s\"",
      build_dir, sketch_dir, ard_build
    );
    if (run_cmd(cmd) != 0) die("Failed to prepare build dirs (mkdir)");
  }
  {
    char libs_root[1024];
    snprintf(libs_root, sizeof(libs_root), "%s/libraries", sketch_dir);
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", libs_root);
    if (run_cmd(cmd) != 0) die("Failed to prepare libraries dir: %s", libs_root);
  }

  // Read JSON configs
  char* cfg = read_file(config_path);
  char* bjs = read_file(boards_path);
  if (!cfg || !bjs) die("Failed to read config/boards json");

  // -----------------------------
  // Board selection
  // -----------------------------
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

  // Resolve swiftc (project-local override supported)
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
  // Copy sketch sources from tool runtime -> project build/sketch
  // -----------------------------
  ok("Preparing Arduino sketch...");
  require_and_copy(runtime_arduino, "sketch.ino", sketch_dir);
  require_and_copy(runtime_arduino, "ArduinoSwiftShim.h", sketch_dir);
  require_and_copy(runtime_arduino, "ArduinoSwiftShim.cpp", sketch_dir);
  require_and_copy(runtime_arduino, "Bridge.cpp", sketch_dir);
  require_and_copy(runtime_arduino, "SwiftRuntimeSupport.c", sketch_dir);

  // -----------------------------
  // Compile Swift: core + selected libs + project main.swift
  // -----------------------------
  char obj[1024];
  snprintf(obj, sizeof(obj), "%s/ArduinoSwiftApp.o", sketch_dir);

  // 1) Core Swift files
  char find_core_cmd[2048];
  snprintf(find_core_cmd, sizeof(find_core_cmd),
    "find \"%s/core\" -type f -name \"*.swift\" -print | sort",
    runtime_swift
  );

  char core_list[65535];
  if (run_cmd_capture(find_core_cmd, core_list, sizeof(core_list)) != 0)
    die("Failed listing Swift core sources");
  if (!core_list[0])
    die("No Swift core sources found in: %s/core", runtime_swift);

  // Build quoted args string (core first)
  char swift_args[200000];
  swift_args[0] = 0;
  append_swift_list_as_args(core_list, swift_args, sizeof(swift_args));

  // 2) Selected libs from config.json
  char libs[64][64];
  int lib_count = parse_lib_array(cfg, libs, 64);

  if (lib_count > 0) {
    ok("Including %d lib(s) from config.json", lib_count);
  } else {
    ok("No libs specified in config.json (\"lib\": [...]) -> using core only");
  }

  // Keep resolved leaf names (actual folder casing) for Arduino libs
  char resolved_leafs[64][64];
  memset(resolved_leafs, 0, sizeof(resolved_leafs));
  int resolved_count = 0;

  for (int i = 0; i < lib_count; i++) {
    const char* libname = libs[i];
    if (!libname || !libname[0]) continue;

    // --- Swift lib dir
    char swift_libdir[1024];
    char swift_leaf[64]={0};
    if (!resolve_swift_lib_dir(runtime_swift, libname,
                               swift_libdir, sizeof(swift_libdir),
                               swift_leaf, sizeof(swift_leaf))) {
      die("Swift lib not found: %s (expected in %s/libs/<LIB>/)", libname, runtime_swift);
    }

    char find_lib_cmd[2048];
    snprintf(find_lib_cmd, sizeof(find_lib_cmd),
      "find \"%s\" -type f -name \"*.swift\" -print | sort",
      swift_libdir
    );

    char lib_list[65535];
    if (run_cmd_capture(find_lib_cmd, lib_list, sizeof(lib_list)) != 0)
      die("Failed listing Swift lib sources: %s", swift_libdir);
    if (!lib_list[0])
      die("No Swift files found in lib dir: %s", swift_libdir);

    ok("Adding Swift lib: %s (%s)", swift_leaf[0] ? swift_leaf : libname, swift_libdir);
    append_swift_list_as_args(lib_list, swift_args, sizeof(swift_args));

    // --- Arduino lib dir (optional: Swift-only libs are allowed)
    char arduino_libdir[1024];
    char arduino_leaf[64]={0};

    if (!resolve_arduino_lib_dir(runtime_arduino, libname,
                                 arduino_libdir, sizeof(arduino_libdir),
                                 arduino_leaf, sizeof(arduino_leaf))) {
      ok("Swift-only lib (no Arduino side): %s", libname);
      continue;
    }

    // Copy into build/sketch/libraries/<ResolvedLeaf>/
    char dst_libdir[1024];
    const char* leaf = (arduino_leaf[0] ? arduino_leaf : libname);
    snprintf(dst_libdir, sizeof(dst_libdir), "%s/libraries/%s", sketch_dir, leaf);

    ok("Copying Arduino lib: %s (%s -> %s)", leaf, arduino_libdir, dst_libdir);
    copy_arduino_lib_recursive(arduino_libdir, dst_libdir);

    // Sanity log: list top-level contents of the copied lib directory
    {
      char cmd[4096];
      snprintf(cmd, sizeof(cmd),
        "echo \"[lib:%s] files:\"; ls -1 \"%s\" 2>/dev/null || true",
        leaf, dst_libdir
      );
      run_cmd(cmd);
    }

    // Track leaf unconditionally (do NOT require <LIB>.h).
    // We copy the whole directory and then force-compile every .c/.cpp inside it.
    if (resolved_count < 64) {
      strncpy(resolved_leafs[resolved_count], leaf, 63);
      resolved_leafs[resolved_count][63] = 0;
      resolved_count++;
    }
  }

  // Generate force-compile TU for Arduino libs
  if (resolved_count > 0) {
    write_lib_includer_cpp(sketch_dir, resolved_leafs, resolved_count);
  }

  // Optional: dump sketch tree for diagnostics (always helpful during bringup)
  debug_dump_sketch_tree(sketch_dir);

  // 3) Project main.swift must exist in project root
  char main_swift[1024];
  snprintf(main_swift, sizeof(main_swift), "%s/main.swift", project_root);
  if (!file_exists(main_swift))
    die("Missing main.swift at project root: %s", main_swift);

  // Add it last
  {
    size_t need = strlen(swift_args) + strlen(main_swift) + 4 + 2;
    if (need >= sizeof(swift_args)) die("Args buffer overflow adding main.swift");
    strcat(swift_args, "\"");
    strcat(swift_args, main_swift);
    strcat(swift_args, "\" ");
  }

  // swiftc command
  char swiftc_cmd[260000];
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
  // arduino-cli compile (inject Swift .o)
  // -----------------------------
  // NOTE:
  // - --build-cache-path is deprecated; do not pass it.
  // - We also pass -fno-short-enums to C/C++ to match Swift's -fno-short-enums usage and reduce warnings.
  // - We inject the Swift object by appending it to compiler.c.elf.extra_flags.
  //
  // If you still see missing symbols, run with:
  //   ARDUINO_CLI_LOG_LEVEL=debug
  // or modify run_cmd to print commands verbosely.
  char cli_cmd[20000];
  snprintf(cli_cmd, sizeof(cli_cmd),
    "arduino-cli compile --clean "
    "--fqbn \"%s\" "
    "--build-path \"%s\" "
    "--build-property \"compiler.c.extra_flags=-fno-short-enums\" "
    "--build-property \"compiler.cpp.extra_flags=-fno-short-enums\" "
    "--build-property \"compiler.c.elf.extra_flags=%s\" "
    "\"%s\"",
    fqbn,
    ard_build,
    obj,
    sketch_dir
  );

  ok("Building with Arduino CLI (FQBN=%s)", fqbn);
  ok("arduino-cli cmd: %s", cli_cmd);

  if (run_cmd(cli_cmd) != 0) {
    ok("Build failed. Sketch tree + lib entrypoints are shown above.");
    die("arduino-cli compile failed");
  }

  ok("Build complete");
  ok("Artifacts: %s", ard_build);

  free(cfg);
  free(bjs);
  return 0;
}