// ============================================================
// File: arduino/libs/wifi/wifi.h
// ArduinoSwift - WiFi C ABI (STA + AP) for Arduino GIGA R1 WiFi
//
// IMPORTANT:
// - All functions MUST be non-blocking.
// - Connection progress must be polled from Swift via _wifi_*_status().
// ============================================================

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// -------- STA --------
int32_t _wifi_sta_begin(const char* ssid, const char* pass); // non-blocking
void    _wifi_sta_disconnect(void);
int32_t _wifi_sta_status(void);
const char* _wifi_sta_ssid(void);
void    _wifi_sta_local_ip(char* out, int32_t outLen);
int32_t _wifi_sta_rssi(void);

// -------- AP --------
int32_t _wifi_ap_begin(const char* ssid, const char* pass);  // non-blocking
void    _wifi_ap_stop(void);
int32_t _wifi_ap_status(void);

#ifdef __cplusplus
} // extern "C"
#endif