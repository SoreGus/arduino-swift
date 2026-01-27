// SwiftRuntimeSupport.cpp
// Minimal shims required by Embedded Swift when linking inside an Arduino core.
// Location: tools/arduino-swift/arduino/commom/SwiftRuntimeSupport.cpp

#include <Arduino.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern "C" {

// -----------------------------
// Serial shims (used by Swift core)
// -----------------------------

static bool g_serial_started = false;
static uint32_t g_serial_baud = 115200;

void arduino_serial_begin(uint32_t baud) {
  if (!g_serial_started || g_serial_baud != baud) {
    g_serial_baud = baud;
    Serial.begin((unsigned long)baud);
    g_serial_started = true;
  }
}

void arduino_serial_print_cstr(const char* s) {
  if (!s) return;
  Serial.print(s);
}

void arduino_serial_print_i32(int32_t v) {
  Serial.print(v);
}

void arduino_serial_print_u32(uint32_t v) {
  Serial.print(v);
}

void arduino_serial_print_f64(double v) {
  // Ajuste a precisão se quiser menos custo
  Serial.print(v, 6);
}

// -----------------------------
// Analog shims (used by AnalogPIN.swift)
// -----------------------------

static uint32_t g_analog_bits = 10;

void arduino_analogReadResolution(uint32_t bits) {
  if (bits == 0) bits = 10;
  g_analog_bits = bits;

  // Arduino Due (sam) suporta analogReadResolution()
  // Em cores que não suportam, isso vira no-op.
  #if defined(ARDUINO_ARCH_SAM) || defined(ARDUINO_SAM_DUE)
    analogReadResolution((int)bits);
  #endif
}

uint32_t arduino_analogMaxValue(void) {
  if (g_analog_bits >= 32) return 0xFFFFFFFFu;
  return (g_analog_bits == 0) ? 0u : ((1u << g_analog_bits) - 1u);
}

uint32_t arduino_analogRead(uint32_t pin) {
  return (uint32_t)analogRead((int)pin);
}

// -----------------------------
// ARM EABI helpers (Swift runtime sometimes needs these)
// -----------------------------

void __aeabi_memclr(void* dest, size_t n)  { memset(dest, 0, n); }
void __aeabi_memclr4(void* dest, size_t n) { memset(dest, 0, n); }
void __aeabi_memclr8(void* dest, size_t n) { memset(dest, 0, n); }

// -----------------------------
// arc4random_buf shim (Swift hashing may call this)
// -----------------------------

static bool g_rng_seeded = false;

void arc4random_buf(void* buf, size_t n) {
  if (!buf || n == 0) return;

  if (!g_rng_seeded) {
    // Seed simples e barato (suficiente pro runtime / hashing).
    randomSeed((unsigned long)micros());
    g_rng_seeded = true;
  }

  uint8_t* p = (uint8_t*)buf;
  while (n--) {
    *p++ = (uint8_t)random(0, 256);
  }
}

// -----------------------------
// posix_memalign shim
// -----------------------------
// O ideal é usar um allocator alinhado real; aqui tentamos memalign/aligned_alloc,
// e se não existir, caímos para malloc (geralmente já é 8/16-aligned no ARM).

int posix_memalign(void** memptr, size_t alignment, size_t size) {
  if (!memptr) return 22; // EINVAL
  *memptr = nullptr;

  if (alignment < sizeof(void*) || (alignment & (alignment - 1)) != 0) {
    return 22; // EINVAL
  }

  void* p = nullptr;

  // newlib costuma ter memalign()
  #if defined(__NEWLIB__)
    // NOLINTNEXTLINE
    extern void* memalign(size_t, size_t);
    p = memalign(alignment, size);
  #endif

  // C11 aligned_alloc (nem sempre existe)
  #if defined(__cpp_aligned_new) || defined(aligned_alloc)
    if (!p) {
      size_t rounded = (size + alignment - 1) & ~(alignment - 1);
      p = aligned_alloc(alignment, rounded);
    }
  #endif

  // Fallback (pode ser suficiente na prática)
  if (!p) {
    p = malloc(size);
  }

  if (!p) return 12; // ENOMEM
  *memptr = p;
  return 0;
}

// -----------------------------
// getentropy shim (newlib/mbed may require this via arc4random.o)
// -----------------------------
int getentropy(void* buf, size_t len) {
  if (!buf) return -1;

  if (!g_rng_seeded) {
    randomSeed((unsigned long)micros());
    g_rng_seeded = true;
  }

  uint8_t* p = (uint8_t*)buf;
  for (size_t i = 0; i < len; i++) {
    p[i] = (uint8_t)random(0, 256);
  }
  return 0;
}

} // extern "C"