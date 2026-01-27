// main.c
//
// ArduinoSwift CLI entrypoint.
//
// This file routes subcommands to their implementations in /commands.
// It intentionally keeps logic minimal: parsing + dispatch only.
//
// Supported commands:
// - verify
// - build (alias: compile)
// - upload
// - monitor
// - all (verify + build + upload + monitor)

#include "util.h"
#include <string.h>

int cmd_verify(int argc, char** argv);
int cmd_build(int argc, char** argv);
int cmd_upload(int argc, char** argv);
int cmd_monitor(int argc, char** argv);

static void usage(void) {
  info("Usage:");
  info("  arduino-swift verify");
  info("  arduino-swift build        (alias: compile)");
  info("  arduino-swift upload");
  info("  arduino-swift monitor");
  info("  arduino-swift all          (verify + build + upload + monitor)");
}

int main(int argc, char** argv) {
  if (argc < 2) { usage(); return 1; }

  const char* sub = argv[1];

  if (!strcmp(sub, "verify"))  return cmd_verify(argc - 1, argv + 1);
  if (!strcmp(sub, "build"))   return cmd_build(argc - 1, argv + 1);
  if (!strcmp(sub, "compile")) return cmd_build(argc - 1, argv + 1);
  if (!strcmp(sub, "upload"))  return cmd_upload(argc - 1, argv + 1);
  if (!strcmp(sub, "monitor")) return cmd_monitor(argc - 1, argv + 1);

  if (!strcmp(sub, "all")) {
    ok("Running: verify");
    if (cmd_verify(argc - 1, argv + 1) != 0) return 1;

    ok("Running: build");
    if (cmd_build(argc - 1, argv + 1) != 0) return 1;

    ok("Running: upload");
    if (cmd_upload(argc - 1, argv + 1) != 0) return 1;

    ok("Running: monitor");
    return cmd_monitor(argc - 1, argv + 1);
  }

  usage();
  return 1;
}