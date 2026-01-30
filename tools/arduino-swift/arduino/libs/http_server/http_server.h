// http_server.h
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int32_t  arduino_http_server_begin(uint16_t port);
void     arduino_http_server_end(void);

int32_t  arduino_http_server_client_available(void);
int32_t  arduino_http_server_client_connected(void);

int32_t  arduino_http_server_client_read(uint8_t* out, uint32_t cap);
int32_t  arduino_http_server_client_write(const uint8_t* data, uint32_t len);

void     arduino_http_server_client_stop(void);

#ifdef __cplusplus
} // extern "C"
#endif