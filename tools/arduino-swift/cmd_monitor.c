#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int cmd_monitor(int argc, char** argv) {
  (void)argc; (void)argv;

  const char* port_env = getenv("PORT");
  const char* baud_env = getenv("BAUD");
  const char* baud = (baud_env && baud_env[0]) ? baud_env : "115200";

  char port[256]={0};
  if (port_env && port_env[0]) {
    strncpy(port, port_env, sizeof(port)-1);
  } else {
    // same logic do seu awk: prefer Arduino Due Programming Port
    char out[8192];
    run_cmd_capture("arduino-cli board list 2>/dev/null", out, sizeof(out));
    // naive: if line contains "Arduino Due" and "Programming Port", take first token
    char* line = strtok(out, "\n");
    while (line) {
      if (strstr(line, "Arduino Due") && strstr(line, "Programming Port")) {
        // first token
        char* sp = strchr(line, ' ');
        if (sp) *sp = 0;
        strncpy(port, line, sizeof(port)-1);
        break;
      }
      line = strtok(NULL, "\n");
    }
    // fallback: first token of second line
    if (!port[0]) {
      run_cmd_capture("arduino-cli board list 2>/dev/null | awk 'NR==2{print $1}'", port, sizeof(port));
      // strip newline
      char* nl = strchr(port, '\n'); if (nl) *nl = 0;
    }
  }

  if (!port[0]) die("No serial port detected. Use: PORT=/dev/cu.usbmodemXXXX arduino-swift monitor");

  ok("Monitor: port=%s baud=%s", port, baud);

  // IMPORTANT: no tee, Ctrl+C works
  char cmd[1024];
  snprintf(cmd, sizeof(cmd),
    "arduino-cli monitor -p \"%s\" -c baudrate=\"%s\"",
    port, baud
  );
  return run_cmd(cmd);
}