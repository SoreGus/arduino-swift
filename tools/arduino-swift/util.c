#define _POSIX_C_SOURCE 200809L
#include "util.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <sys/stat.h>
#include <unistd.h>
#include <limits.h>
#include <sys/wait.h>

#if defined(__APPLE__)
  #include <mach-o/dyld.h>
#endif

static char g_exe_dir[PATH_MAX] = {0};

static void dirname_inplace(char* p) {
  if (!p || !p[0]) return;
  char* slash = strrchr(p, '/');
  if (slash) *slash = 0;
  else strcpy(p, ".");
}

static void init_exe_dir(void) {
  if (g_exe_dir[0]) return;

  char path[PATH_MAX] = {0};

#if defined(__APPLE__)
  uint32_t sz = (uint32_t)sizeof(path);
  if (_NSGetExecutablePath(path, &sz) == 0) {
    // best-effort resolve relative segments
    char realp[PATH_MAX] = {0};
    if (realpath(path, realp)) {
      strncpy(path, realp, sizeof(path)-1);
    }
  } else {
    // fallback
    if (!getcwd(path, sizeof(path))) strncpy(path, ".", sizeof(path)-1);
  }

#elif defined(__linux__)
  ssize_t n = readlink("/proc/self/exe", path, sizeof(path)-1);
  if (n > 0) {
    path[n] = 0;
  } else {
    if (!getcwd(path, sizeof(path))) strncpy(path, ".", sizeof(path)-1);
  }

#else
  if (!getcwd(path, sizeof(path))) strncpy(path, ".", sizeof(path)-1);
#endif

  dirname_inplace(path);
  strncpy(g_exe_dir, path, sizeof(g_exe_dir)-1);
}

const char* exe_dir(void) {
  init_exe_dir();
  return g_exe_dir;
}

const char* cwd_dir(char* out, size_t cap) {
  if (!out || cap == 0) return NULL;
  if (!getcwd(out, cap)) return NULL;
  out[cap-1] = 0;
  return out;
}

int path_join(char* out, size_t cap, const char* a, const char* b) {
  if (!out || cap == 0) return 0;
  out[0] = 0;
  if (!a) a = "";
  if (!b) b = "";

  size_t la = strlen(a);
  size_t lb = strlen(b);

  int need_slash = 0;
  if (la > 0 && a[la-1] != '/') need_slash = 1;
  if (la == 0) need_slash = 0;
  if (lb > 0 && b[0] == '/') need_slash = 0;

  // compute required
  size_t req = la + (need_slash ? 1 : 0) + lb + 1;
  if (req > cap) return 0;

  strcpy(out, a);
  if (need_slash) strcat(out, "/");
  strcat(out, b);
  return 1;
}

int file_exists(const char* path) {
  struct stat st;
  return (stat(path, &st) == 0) && S_ISREG(st.st_mode);
}

int dir_exists(const char* path) {
  struct stat st;
  return (stat(path, &st) == 0) && S_ISDIR(st.st_mode);
}

int ensure_dir(const char* path) {
  if (dir_exists(path)) return 1;
#ifdef _WIN32
  return 0;
#else
  return mkdir(path, 0755) == 0;
#endif
}

char* read_file(const char* path) {
  FILE* f = fopen(path, "rb");
  if (!f) return NULL;
  fseek(f, 0, SEEK_END);
  long sz = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (sz < 0) { fclose(f); return NULL; }

  char* buf = (char*)malloc((size_t)sz + 1);
  if (!buf) { fclose(f); return NULL; }

  if (fread(buf, 1, (size_t)sz, f) != (size_t)sz) {
    fclose(f);
    free(buf);
    return NULL;
  }
  buf[sz] = 0;
  fclose(f);
  return buf;
}

int write_file(const char* path, const char* s) {
  FILE* f = fopen(path, "wb");
  if (!f) return 0;
  size_t n = strlen(s);
  if (fwrite(s, 1, n, f) != n) { fclose(f); return 0; }
  fclose(f);
  return 1;
}

int run_cmd(const char* cmd) {
  info("%s", cmd);
  int rc = system(cmd);
  if (rc == -1) return 127;
  if (WIFEXITED(rc)) return WEXITSTATUS(rc);
  return 127;
}

int run_cmd_capture(const char* cmd, char* out, size_t out_cap) {
  if (out_cap) out[0] = 0;
  FILE* p = popen(cmd, "r");
  if (!p) return 127;

  size_t used = 0;
  while (!feof(p) && used + 1 < out_cap) {
    int c = fgetc(p);
    if (c == EOF) break;
    out[used++] = (char)c;
  }
  if (out_cap) out[used] = 0;

  int rc = pclose(p);
  if (rc == -1) return 127;
  if (WIFEXITED(rc)) return WEXITSTATUS(rc);
  return 127;
}

int prompt_yes_no(const char* q, int def_yes) {
  if (!isatty(STDIN_FILENO)) return def_yes;

  printf("%s [%s]: ", q, def_yes ? "Y/n" : "y/N");
  fflush(stdout);

  char line[32];
  if (!fgets(line, sizeof line, stdin)) return def_yes;
  if (line[0] == '\n' || line[0] == 0) return def_yes;
  if (line[0] == 'y' || line[0] == 'Y') return 1;
  return 0;
}

static void vlogf(int is_err, const char* tag, const char* fmt, va_list ap) {
  FILE* f = is_err ? stderr : stdout;
  fprintf(f, "%s", tag);
  vfprintf(f, fmt, ap);
  fprintf(f, "\n");
}

void die(const char* fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vlogf(1, "[ERR] ", fmt, ap);
  va_end(ap);
  exit(1);
}

void info(const char* fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vlogf(0, "[INFO] ", fmt, ap);
  va_end(ap);
}

void ok(const char* fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vlogf(0, "[OK] ", fmt, ap);
  va_end(ap);
}

void warn(const char* fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vlogf(1, "[WARN] ", fmt, ap);
  va_end(ap);
}