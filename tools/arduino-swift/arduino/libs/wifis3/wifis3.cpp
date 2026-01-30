// wifis3.cpp
#include <Arduino.h>
#include "wifis3.h"
#include <WiFiS3.h>   // UNO R4 WiFi

static inline uint32_t pack_ip_u32(const IPAddress& ip) {
  return ((uint32_t)ip[0] << 24) |
         ((uint32_t)ip[1] << 16) |
         ((uint32_t)ip[2] <<  8) |
         ((uint32_t)ip[3] <<  0);
}

static inline bool ip_is_zero(const IPAddress& ip) {
  return (ip[0] == 0 && ip[1] == 0 && ip[2] == 0 && ip[3] == 0);
}

static inline uint32_t copy_string_to_buf(const String& s, char* out, uint32_t cap) {
  if (!out || cap == 0) return 0;
  uint32_t n = (uint32_t)s.length();
  if (n >= cap) n = cap - 1;
  for (uint32_t i = 0; i < n; i++) out[i] = (char)s[i];
  out[n] = 0;
  return n;
}

extern "C" {

uint32_t arduino_wifis3_isAvailable(void) {
  return (WiFi.status() == WL_NO_MODULE) ? 0u : 1u;
}

int32_t arduino_wifis3_begin_ssid_pass(const char* ssid, const char* pass) {
  if (!ssid) return (int32_t)WiFi.status();
  if (!pass) return (int32_t)WiFi.begin(ssid);
  return (int32_t)WiFi.begin(ssid, pass);
}

int32_t arduino_wifis3_begin_ssid(const char* ssid) {
  if (!ssid) return (int32_t)WiFi.status();
  return (int32_t)WiFi.begin(ssid);
}

int32_t arduino_wifis3_disconnect(void) {
  return (int32_t)WiFi.disconnect();
}

int32_t arduino_wifis3_status(void) {
  return (int32_t)WiFi.status();
}

int32_t arduino_wifis3_rssi(void) {
  return (int32_t)WiFi.RSSI();
}

uint32_t arduino_wifis3_localIP_u32(void) {
  return pack_ip_u32(WiFi.localIP());
}

uint32_t arduino_wifis3_gatewayIP_u32(void) {
  return pack_ip_u32(WiFi.gatewayIP());
}

uint32_t arduino_wifis3_subnetMask_u32(void) {
  return pack_ip_u32(WiFi.subnetMask());
}

void arduino_wifis3_macAddress(uint8_t* out6) {
  if (!out6) return;
  WiFi.macAddress(out6);
}

uint32_t arduino_wifis3_firmwareVersion(char* out, uint32_t cap) {
  return copy_string_to_buf(WiFi.firmwareVersion(), out, cap);
}

uint32_t arduino_wifis3_ssid(char* out, uint32_t cap) {
  return copy_string_to_buf(WiFi.SSID(), out, cap);
}

// ---- Scan ----

int32_t arduino_wifis3_scanNetworks(void) {
  return (int32_t)WiFi.scanNetworks();
}

// WiFiS3 (Renesas UNO core) não tem scanDelete() → NO-OP
void arduino_wifis3_scanDelete(void) { }

uint32_t arduino_wifis3_scan_ssid(int32_t index, char* out, uint32_t cap) {
  return copy_string_to_buf(WiFi.SSID((int)index), out, cap);
}

int32_t arduino_wifis3_scan_rssi(int32_t index) {
  return (int32_t)WiFi.RSSI((int)index);
}

int32_t arduino_wifis3_scan_encryptionType(int32_t index) {
  return (int32_t)WiFi.encryptionType((int)index);
}

// ---- Helper: wait IP != 0.0.0.0 ----

uint32_t arduino_wifis3_waitLocalIP_u32(uint32_t timeoutMs, uint32_t pollMs) {
  uint32_t start = (uint32_t)millis();
  while (true) {
    IPAddress ip = WiFi.localIP();
    if (!ip_is_zero(ip)) return pack_ip_u32(ip);

    uint32_t now = (uint32_t)millis();
    if ((uint32_t)(now - start) >= timeoutMs) return 0u;

    delay(pollMs);
  }
}

} // extern "C"