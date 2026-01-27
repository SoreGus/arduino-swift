// renesas_r4_runtime_support.c
//
// Minimal runtime shims for Embedded Swift on Arduino UNO R4 Minima (Renesas RA4M1).
// Pure C. Do NOT include Arduino.h.
//
// Purpose:
// - Satisfy symbols required by Embedded Swift runtime
// - Avoid pulling full POSIX/libc features
// - Deterministic + linker-safe
//
// Notes:
// - ARM EABI helpers included to avoid missing symbols
// - Provides end/_end symbols to satisfy link expectations

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================
// Swift heap allocation hooks
// ============================================================

void *swift_slowAlloc(size_t size, size_t alignMask) {
    (void)alignMask;
    return malloc(size);
}

void swift_slowDealloc(void *ptr, size_t size, size_t alignMask) {
    (void)size;
    (void)alignMask;
    free(ptr);
}

// ============================================================
// posix_memalign (Swift runtime expects this symbol)
//
// We deliberately IGNORE alignment and return malloc() memory,
// so free(ptr) is always safe.
// ============================================================

int posix_memalign(void **memptr, size_t alignment, size_t size) {
    (void)alignment;
    if (!memptr) return 22; // EINVAL

    void *p = malloc(size);
    if (!p) return 12; // ENOMEM

    *memptr = p;
    return 0;
}

// ============================================================
// ARM EABI memory helpers (sometimes missing in link)
// ============================================================

void __aeabi_memclr(void *dest, size_t n)  { memset(dest, 0, n); }
void __aeabi_memclr4(void *dest, size_t n) { memset(dest, 0, n); }
void __aeabi_memclr8(void *dest, size_t n) { memset(dest, 0, n); }

void __aeabi_memcpy(void *dest, const void *src, size_t n)  { memcpy(dest, src, n); }
void __aeabi_memcpy4(void *dest, const void *src, size_t n) { memcpy(dest, src, n); }
void __aeabi_memcpy8(void *dest, const void *src, size_t n) { memcpy(dest, src, n); }

void __aeabi_memmove(void *dest, const void *src, size_t n)  { memmove(dest, src, n); }
void __aeabi_memmove4(void *dest, const void *src, size_t n) { memmove(dest, src, n); }
void __aeabi_memmove8(void *dest, const void *src, size_t n) { memmove(dest, src, n); }

// ============================================================
// arc4random_buf (used by Swift hashing)
// NOT cryptographically secure — deterministic
// ============================================================

static uint32_t g_rng_state = 0x12345678u;

static uint32_t swift_xorshift32(void) {
    uint32_t x = g_rng_state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    g_rng_state = x;
    return x;
}

void arc4random_buf(void *buf, size_t n) {
    uint8_t *p = (uint8_t *)buf;
    while (n) {
        uint32_t r = swift_xorshift32();
        for (int i = 0; i < 4 && n; i++, n--) {
            *p++ = (uint8_t)(r & 0xFF);
            r >>= 8;
        }
    }
}

// ============================================================
// Fatal / trap paths (Embedded Swift expects these)
// ============================================================

__attribute__((noreturn))
static void swift_trap_forever(void) {
    for (;;) { }
}

__attribute__((noreturn))
void swift_unexpectedError(void *error) {
    (void)error;
    swift_trap_forever();
}

__attribute__((noreturn))
void swift_abortRetainUnowned(const void *obj) {
    (void)obj;
    swift_trap_forever();
}

__attribute__((noreturn))
void swift_abortUnownedRetain(const void *obj) {
    (void)obj;
    swift_trap_forever();
}

__attribute__((noreturn))
void swift_abortDynamicReplacementDisallowed(void) {
    swift_trap_forever();
}

__attribute__((noreturn))
void swift_reportFatalError(const char *msg, intptr_t len) {
    (void)msg;
    (void)len;
    swift_trap_forever();
}

__attribute__((noreturn))
void swift_assertionFailure(const char *prefix,
                            const char *message,
                            const char *file,
                            uint32_t line,
                            const char *flags) {
    (void)prefix;
    (void)message;
    (void)file;
    (void)line;
    (void)flags;
    swift_trap_forever();
}

__attribute__((noreturn))
void swift_fatalError(const char *message, intptr_t len) {
    (void)message;
    (void)len;
    swift_trap_forever();
}

#if defined(__cplusplus)
} // extern "C"
#endif

// ------------------------------------------------------------
// Linker symbols that some builds expect
// ------------------------------------------------------------

// Some toolchains expect `end`, some expect `_end`.
// Provide both so your build-property `--defsym` can stop breaking.
__attribute__((used)) char end;
__attribute__((used)) char _end;