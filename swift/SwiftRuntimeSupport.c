// SwiftRuntimeSupport.c
// Minimal stubs to satisfy Swift runtime symbols in embedded builds.

#include <stdint.h>
#include <stddef.h>

// A tiny deterministic PRNG (xorshift32). Good enough for "random seed" needs here.
static uint32_t g_seed = 0x12345678u;
static uint32_t xorshift32(void) {
  uint32_t x = g_seed;
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  g_seed = x;
  return x;
}

// arc4random_buf stub used by Swift stdlib hashing parameters
void arc4random_buf(void *buf, size_t n) {
  uint8_t *p = (uint8_t *)buf;
  for (size_t i = 0; i < n; i++) {
    if ((i & 3u) == 0u) {
      uint32_t r = xorshift32();
      p[i] = (uint8_t)(r & 0xFFu);
    } else {
      uint32_t r = g_seed;
      p[i] = (uint8_t)((r >> ((i & 3u) * 8u)) & 0xFFu);
    }
  }
}