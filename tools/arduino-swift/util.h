#pragma once
#include <stddef.h>

typedef struct {
  int code;
  char msg[512];
} Result;

// directory where the executable lives
const char* exe_dir(void);

// current working directory (fills out, returns out or NULL)
const char* cwd_dir(char* out, size_t cap);

// join paths safely: out = a + "/" + b (handles existing slash)
int path_join(char* out, size_t cap, const char* a, const char* b);

int file_exists(const char* path);
int dir_exists(const char* path);
int ensure_dir(const char* path);

char* read_file(const char* path);      // malloc
int write_file(const char* path, const char* s);

int run_cmd(const char* cmd);           // prints cmd, returns exit code
int run_cmd_capture(const char* cmd, char* out, size_t out_cap); // popen

int prompt_yes_no(const char* q, int def_yes);

void die(const char* fmt, ...);
void info(const char* fmt, ...);
void ok(const char* fmt, ...);
void warn(const char* fmt, ...);