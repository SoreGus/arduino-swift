// proc_helpers.c
#include "proc_helpers.h"
#include "build_log.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static FILE* fopen_append_or_create(const char* path) {
    if (!path || !path[0]) return NULL;
    return fopen(path, "ab");
}

int proc_mkdir_parent_for_file(const char* path) {
    if (!path || !path[0]) return 0;

    char tmp[1024];
    size_t n = strlen(path);
    if (n >= sizeof(tmp)) return 0;
    strcpy(tmp, path);

    char* slash = strrchr(tmp, '/');
    if (!slash) return 1;
    *slash = 0;

    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", tmp);
    return system(cmd) == 0 ? 1 : 0;
}

int proc_run_tee(const char* cmd, const char* log_path, int verbose) {
    if (!cmd || !cmd[0]) return 1;

    if (log_path && log_path[0]) (void)proc_mkdir_parent_for_file(log_path);

    char full_cmd[8192];
    snprintf(full_cmd, sizeof(full_cmd), "%s 2>&1", cmd);

    FILE* pipe = popen(full_cmd, "r");
    if (!pipe) {
        log_error("Failed to popen command");
        return 1;
    }

    FILE* logf = fopen_append_or_create(log_path);
    if (log_path && log_path[0] && !logf) {
        log_warn("Could not open log file: %s", log_path);
    }

    char buf[4096];
    while (fgets(buf, sizeof(buf), pipe)) {
        if (logf) fwrite(buf, 1, strlen(buf), logf);
        if (verbose) fputs(buf, stdout);
    }

    if (logf) fclose(logf);

    int status = pclose(pipe);
    if (status != 0) return status;
    return 0;
}

int proc_tail_file(const char* path, int max_lines) {
    if (!path || !path[0]) return 0;
    if (max_lines <= 0) return 0;

    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "tail -n %d \"%s\" 2>/dev/null", max_lines, path);
    return system(cmd) == 0 ? 1 : 0;
}
