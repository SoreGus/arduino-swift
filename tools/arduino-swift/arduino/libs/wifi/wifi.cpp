// ============================================================
// File: arduino/libs/wifi/wifi.cpp
// ArduinoSwift - WiFi C++ bridge (STA + AP) for Arduino GIGA R1 WiFi
//
// Purpose:
// - Provide a small C ABI for Swift to control WiFi without Arduino headers.
// - Expose status/SSID/RSSI/IP as plain C types.
// - Works with cores where WiFi.SSID() returns either String OR char*.
//
// Notes:
// - DO NOT put C++ overloads inside extern "C" (C linkage forbids overload).
// ============================================================

#include <Arduino.h>
#include <WiFi.h>
#include <WString.h> // Arduino String

// ------------------------------
// Internal helpers (C++ only)
// ------------------------------

static inline void _copy_cstr(char* out, int32_t outLen, const char* src) {
    if (!out || outLen <= 0) return;
    if (!src) {
        out[0] = 0;
        return;
    }
    int32_t i = 0;
    for (; i < outLen - 1 && src[i]; i++) out[i] = src[i];
    out[i] = 0;
}

static inline void _ip_to_cstr(char* out, int32_t outLen, const IPAddress& ip) {
    if (!out || outLen <= 0) return;
    char buf[16];
    int n = snprintf(buf, sizeof(buf), "%u.%u.%u.%u",
                     (unsigned)ip[0], (unsigned)ip[1],
                     (unsigned)ip[2], (unsigned)ip[3]);
    if (n <= 0) {
        out[0] = 0;
        return;
    }
    _copy_cstr(out, outLen, buf);
}

// This is the key portability helper: convert SSID() return type to const char*.
// IMPORTANT: This must stay OUTSIDE extern "C" (overloads).
static inline const char* _ssid_cstr(const char* s) { return s ? s : ""; }
static inline const char* _ssid_cstr(char* s)       { return s ? s : ""; }
static inline const char* _ssid_cstr(const String& s) { return s.c_str(); }

extern "C" {

// ------------------------------
// Debug ping
// ------------------------------

int32_t _wifi_debug_ping(void) {
    Serial.println("### wifi: debug ping (C++)");
    return 1234;
}

// ------------------------------
// STA (station) API
// ------------------------------

int32_t _wifi_sta_begin(const char* ssid, const char* pass) {
    Serial.println("### _wifi_sta_begin: ENTER");
    Serial.print("### ssid="); Serial.println(ssid ? ssid : "(null)");
    Serial.print("### pass="); Serial.println(pass ? pass : "(null)");

    Serial.println("### calling WiFi.begin...");
    int r = WiFi.begin(ssid, pass);
    Serial.print("### WiFi.begin ret="); Serial.println(r);

    Serial.println("### _wifi_sta_begin: EXIT");
    return (int32_t)r;
}

void _wifi_sta_disconnect(void) {
    Serial.println("### _wifi_sta_disconnect");
    WiFi.disconnect();
}

int32_t _wifi_sta_status(void) {
    return (int32_t)WiFi.status();
}

const char* _wifi_sta_ssid(void) {
    static char ssidBuf[33]; // SSID max 32 chars + null
    ssidBuf[0] = 0;

    // Works whether WiFi.SSID() returns String or char*
    auto s = WiFi.SSID();
    _copy_cstr(ssidBuf, (int32_t)sizeof(ssidBuf), _ssid_cstr(s));

    return ssidBuf;
}

void _wifi_sta_local_ip(char* out, int32_t outLen) {
    IPAddress ip = WiFi.localIP();
    _ip_to_cstr(out, outLen, ip);
}

int32_t _wifi_sta_rssi(void) {
    return (int32_t)WiFi.RSSI();
}

// ------------------------------
// AP (soft access point) API
// ------------------------------

int32_t _wifi_ap_begin(const char* ssid, const char* pass) {
    Serial.println("### _wifi_ap_begin: ENTER");
    Serial.print("### ap ssid="); Serial.println(ssid ? ssid : "(null)");
    Serial.print("### ap pass="); Serial.println(pass ? pass : "(null)");

    Serial.println("### calling WiFi.beginAP...");
    int r = WiFi.beginAP(ssid, pass);
    Serial.print("### WiFi.beginAP ret="); Serial.println(r);

    Serial.println("### _wifi_ap_begin: EXIT");
    return (int32_t)r;
}

void _wifi_ap_stop(void) {
    Serial.println("### _wifi_ap_stop");
    WiFi.end();
}

int32_t _wifi_ap_status(void) {
    return (int32_t)WiFi.status();
}

} // extern "C"