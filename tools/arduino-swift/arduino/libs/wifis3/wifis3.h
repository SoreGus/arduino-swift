// wifis3.h
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t arduino_wifis3_isAvailable(void);

int32_t  arduino_wifis3_begin_ssid_pass(const char* ssid, const char* pass);
int32_t  arduino_wifis3_begin_ssid(const char* ssid);
int32_t  arduino_wifis3_disconnect(void);
int32_t  arduino_wifis3_status(void);

int32_t  arduino_wifis3_rssi(void);
uint32_t arduino_wifis3_localIP_u32(void);
uint32_t arduino_wifis3_gatewayIP_u32(void);
uint32_t arduino_wifis3_subnetMask_u32(void);
void     arduino_wifis3_macAddress(uint8_t* out6);

uint32_t arduino_wifis3_firmwareVersion(char* out, uint32_t cap);
uint32_t arduino_wifis3_ssid(char* out, uint32_t cap);

// Scan (opcional)
int32_t  arduino_wifis3_scanNetworks(void);
void     arduino_wifis3_scanDelete(void); // no-op (WiFiS3 não tem scanDelete)
uint32_t arduino_wifis3_scan_ssid(int32_t index, char* out, uint32_t cap);
int32_t  arduino_wifis3_scan_rssi(int32_t index);
int32_t  arduino_wifis3_scan_encryptionType(int32_t index);

// Helper: espera IP != 0.0.0.0
uint32_t arduino_wifis3_waitLocalIP_u32(uint32_t timeoutMs, uint32_t pollMs);

#ifdef __cplusplus
}
#endif