// wifi.h
// arduinoSwift core - wifi (giga r1) c-abi
//
// goals:
// - expose a stable c abi for swift.
// - keep the api small and practical (sta + ap + status + ip + scan).
// - avoid returning c++ types; prefer integers and out-buffers.
//
// notes:
// - intended for arduino giga r1 wifi (arduinocore-mbed).
// - uses <WiFi.h> from the installed board core (no external user library required).

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ------------------------------------------------------------
// status
// ------------------------------------------------------------

// returns raw status from WiFi.status()
int32_t arduino_wifi_status(void);

// ------------------------------------------------------------
// sta (station) connect/disconnect
// ------------------------------------------------------------

// connect to a wpa/wpa2 network (ssid + pass)
// returns status (raw)
int32_t arduino_wifi_sta_begin(const char* ssid, const char* pass);

// connect to an open network (ssid only)
// returns status (raw)
int32_t arduino_wifi_sta_begin_open(const char* ssid);

// disconnect from current network
void arduino_wifi_disconnect(void);

// shutdown wifi stack if supported
void arduino_wifi_end(void);

// ------------------------------------------------------------
// ap (access point) start/stop
// ------------------------------------------------------------

// start access point with optional password
// - if pass is null or empty, attempts open ap (if core supports it).
// returns status (raw)
int32_t arduino_wifi_ap_begin(const char* ssid, const char* pass);

// stop access point if supported (fallback: WiFi.end())
void arduino_wifi_ap_end(void);

// ------------------------------------------------------------
// info: ssid, rssi, ip
// ------------------------------------------------------------

// get current connected ssid (sta). writes a null-terminated string.
// returns number of bytes written (excluding null) or 0 if not available.
uint32_t arduino_wifi_ssid(char* out, uint32_t out_len);

// get rssi for current connection (sta). returns 0 if not available.
int32_t arduino_wifi_rssi(void);

// get local ip (sta) as dotted string into out buffer.
// returns bytes written (excluding null) or 0 if not available.
uint32_t arduino_wifi_local_ip(char* out, uint32_t out_len);

// try to get ap ip (if core supports). if not supported, returns 0.
uint32_t arduino_wifi_ap_ip(char* out, uint32_t out_len);

// ------------------------------------------------------------
// scan
// ------------------------------------------------------------

// start scan and return number of networks found (>=0), negative on error.
int32_t arduino_wifi_scan_begin(void);

// get ssid for scan result by index into out buffer.
// returns bytes written (excluding null) or 0.
uint32_t arduino_wifi_scan_ssid(int32_t index, char* out, uint32_t out_len);

// get rssi for scan result by index.
int32_t arduino_wifi_scan_rssi(int32_t index);

// get encryption type for scan result by index (raw int).
int32_t arduino_wifi_scan_encryption(int32_t index);

// clear scan results if supported (otherwise no-op).
void arduino_wifi_scan_end(void);

uint32_t arduino_wifi_local_ip_raw(uint8_t out4[4]);

#ifdef __cplusplus
} // extern "C"
#endif