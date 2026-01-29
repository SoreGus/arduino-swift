// wifi.cpp (PATCH)
// - remove snprintf usage in IP formatting
// - format IPv4 manually into the provided buffer (no stdio)

// ... keep your includes
#include <Arduino.h>
#include <WiFi.h>
#include "wifi.h"

static inline uint32_t write_cstr(char* out, uint32_t out_len, const char* s) {
  if (!out || out_len == 0 || !s) return 0;

  uint32_t i = 0;
  while (i + 1 < out_len && s[i] != '\0') {
    out[i] = s[i];
    i++;
  }
  out[i] = '\0';
  return i;
}

// ---- NEW: tiny helpers to write decimal without printf ----

static inline void out_ch(char* out, uint32_t out_len, uint32_t& i, char c) {
  if (!out || out_len == 0) return;
  if (i + 1 < out_len) { // keep room for '\0'
    out[i++] = c;
  }
}

static inline void out_u8_dec(char* out, uint32_t out_len, uint32_t& i, uint8_t v) {
  // Write v as decimal (0..255) without leading zeros.
  if (v >= 100) {
    out_ch(out, out_len, i, char('0' + (v / 100)));
    v = uint8_t(v % 100);
    out_ch(out, out_len, i, char('0' + (v / 10)));
    out_ch(out, out_len, i, char('0' + (v % 10)));
  } else if (v >= 10) {
    out_ch(out, out_len, i, char('0' + (v / 10)));
    out_ch(out, out_len, i, char('0' + (v % 10)));
  } else {
    out_ch(out, out_len, i, char('0' + v));
  }
}

static inline uint32_t write_ipv4(char* out, uint32_t out_len, const uint8_t ip[4]) {
  if (!out || out_len < 8) { // minimal "0.0.0.0" + '\0' => 8
    return 0;
  }

  uint32_t i = 0;
  out_u8_dec(out, out_len, i, ip[0]);
  out_ch(out, out_len, i, '.');
  out_u8_dec(out, out_len, i, ip[1]);
  out_ch(out, out_len, i, '.');
  out_u8_dec(out, out_len, i, ip[2]);
  out_ch(out, out_len, i, '.');
  out_u8_dec(out, out_len, i, ip[3]);

  // null terminate
  if (i < out_len) out[i] = '\0';
  else out[out_len - 1] = '\0';

  return i; // bytes excluding '\0'
}

extern "C" {

int32_t arduino_wifi_status(void) {
  return (int32_t)WiFi.status();
}

int32_t arduino_wifi_sta_begin(const char* ssid, const char* pass) {
  if (!ssid || ssid[0] == '\0') return -1;
  return (int32_t)WiFi.begin(ssid, pass ? pass : "");
}

int32_t arduino_wifi_sta_begin_open(const char* ssid) {
  if (!ssid || ssid[0] == '\0') return -1;
  return (int32_t)WiFi.begin(ssid);
}

void arduino_wifi_disconnect(void) { WiFi.disconnect(); }
void arduino_wifi_end(void) { WiFi.end(); }

int32_t arduino_wifi_ap_begin(const char* ssid, const char* pass) {
  if (!ssid || ssid[0] == '\0') return -1;
  const char* p = (pass && pass[0] != '\0') ? pass : "";
  return (int32_t)WiFi.beginAP(ssid, p, DEFAULT_AP_CHANNEL);
}

void arduino_wifi_ap_end(void) { WiFi.end(); }

uint32_t arduino_wifi_ssid(char* out, uint32_t out_len) {
  String s = WiFi.SSID();
  if (!s.length()) return 0;
  return write_cstr(out, out_len, s.c_str());
}

int32_t arduino_wifi_rssi(void) {
  return (int32_t)WiFi.RSSI();
}

// ---- PATCHED: no snprintf here ----
uint32_t arduino_wifi_local_ip(char* out, uint32_t out_len) {
  // Extra defensive: only try if status is connected
  if ((int)WiFi.status() != WL_CONNECTED) return 0;

  IPAddress ip = WiFi.localIP();

  uint8_t b[4] = { (uint8_t)ip[0], (uint8_t)ip[1], (uint8_t)ip[2], (uint8_t)ip[3] };
  if (b[0] == 0 && b[1] == 0 && b[2] == 0 && b[3] == 0) return 0;

  return write_ipv4(out, out_len, b);
}

uint32_t arduino_wifi_ap_ip(char* out, uint32_t out_len) {
  (void)out; (void)out_len;
  return 0;
}

int32_t arduino_wifi_scan_begin(void) {
  return (int32_t)WiFi.scanNetworks();
}

uint32_t arduino_wifi_scan_ssid(int32_t index, char* out, uint32_t out_len) {
  if (index < 0) return 0;
  String s = WiFi.SSID(index);
  if (!s.length()) return 0;
  return write_cstr(out, out_len, s.c_str());
}

int32_t arduino_wifi_scan_rssi(int32_t index) {
  if (index < 0) return 0;
  return (int32_t)WiFi.RSSI(index);
}

int32_t arduino_wifi_scan_encryption(int32_t index) {
  if (index < 0) return 0;
  return (int32_t)WiFi.encryptionType(index);
}

uint32_t arduino_wifi_local_ip_raw(uint8_t out4[4]) {
  if (!out4) return 0;

  IPAddress ip = WiFi.localIP();

  // treat 0.0.0.0 as "not available"
  if (ip[0] == 0 && ip[1] == 0 && ip[2] == 0 && ip[3] == 0) return 0;

  out4[0] = (uint8_t)ip[0];
  out4[1] = (uint8_t)ip[1];
  out4[2] = (uint8_t)ip[2];
  out4[3] = (uint8_t)ip[3];
  return 4;
}

void arduino_wifi_scan_end(void) {
#if defined(ARDUINO_ARCH_ESP32) || defined(ARDUINO_ARCH_ESP8266)
  WiFi.scanDelete();
#else
  // no-op on mbed giga
#endif
}

} // extern "C"