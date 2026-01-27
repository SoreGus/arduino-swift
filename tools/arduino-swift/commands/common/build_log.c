// build_log.c
#include "build_log.h"

#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#  include <io.h>
#  define isatty _isatty
#  define fileno _fileno
#else
#  include <unistd.h>
#endif

static int g_verbose = 0;
static int g_use_color = 0;

static const char* C_RESET = "\033[0m";
static const char* C_DIM   = "\033[2m";
static const char* C_RED   = "\033[31m";
static const char* C_GRN   = "\033[32m";
static const char* C_YLW   = "\033[33m";
static const char* C_BLU   = "\033[34m";
static const char* C_CYN   = "\033[36m";
static const char* C_WHT   = "\033[37m";

void log_init(void) {
    const char* v = getenv("ARDUINO_SWIFT_VERBOSE");
    g_verbose = (v && v[0] && strcmp(v, "0") != 0) ? 1 : 0;
    g_use_color = isatty(fileno(stdout)) ? 1 : 0;
}

int log_is_verbose(void) { return g_verbose; }

void log_vprintf(FILE* out, const char* prefix, const char* color, const char* fmt, va_list ap) {
    if (!out) out = stdout;

    if (g_use_color && color) fputs(color, out);
    if (prefix) fputs(prefix, out);
    if (g_use_color && color) fputs(C_RESET, out);

    vfprintf(out, fmt, ap);
    fputc('\n', out);
    fflush(out);
}

static void log_printf(FILE* out, const char* prefix, const char* color, const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    log_vprintf(out, prefix, color, fmt, ap);
    va_end(ap);
}

void log_info(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    log_vprintf(stdout, "[info] ", g_use_color ? C_BLU : NULL, fmt, ap);
    va_end(ap);
}

void log_warn(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    log_vprintf(stdout, "[warn] ", g_use_color ? C_YLW : NULL, fmt, ap);
    va_end(ap);
}

void log_error(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    log_vprintf(stderr, "[err ] ", g_use_color ? C_RED : NULL, fmt, ap);
    va_end(ap);
}

void log_cmd(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);

    if (g_use_color) fputs(C_DIM, stdout);
    if (g_use_color) fputs(C_CYN, stdout);
    fputs("[cmd ] ", stdout);
    if (g_use_color) fputs(C_RESET, stdout);
    if (g_use_color) fputs(C_DIM, stdout);

    vfprintf(stdout, fmt, ap);

    if (g_use_color) fputs(C_RESET, stdout);
    fputc('\n', stdout);
    fflush(stdout);

    va_end(ap);
}

void log_step_begin(const char* step_name) {
    if (!step_name) step_name = "(step)";
    if (g_use_color) fputs(C_WHT, stdout);
    fputs("[step] ", stdout);
    if (g_use_color) fputs(C_RESET, stdout);
    if (g_use_color) fputs(C_BLU, stdout);
    fputs(step_name, stdout);
    if (g_use_color) fputs(C_RESET, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

void log_step_ok(void) {
    if (g_use_color) fputs(C_GRN, stdout);
    fputs("[ ok ] ", stdout);
    if (g_use_color) fputs(C_RESET, stdout);
    fputs("done", stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

void log_step_fail(const char* fmt, ...) {
    if (g_use_color) fputs(C_RED, stdout);
    fputs("[fail] ", stdout);
    if (g_use_color) fputs(C_RESET, stdout);

    va_list ap;
    va_start(ap, fmt);
    vfprintf(stdout, fmt, ap);
    va_end(ap);

    fputc('\n', stdout);
    fflush(stdout);
}

void log_sep(void) {
    if (g_use_color) fputs(C_DIM, stdout);
    fputs("------------------------------------------------------------", stdout);
    if (g_use_color) fputs(C_RESET, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}
