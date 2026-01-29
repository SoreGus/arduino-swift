// ============================================================
// ArduinoSwift - Socket Library (TCP) C ABI Bridge
// File: arduino/libs/socket/socket.h
//
// This library exposes a minimal TCP client/server interface backed by:
// - WiFiClient
// - WiFiServer
//
// Opaque handles are pointers to C++ objects, safe to pass through Swift.
// ============================================================
#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* socket_server_t;
typedef void* socket_client_t;

// Server
socket_server_t socket_server_create(uint16_t port);
void            socket_server_destroy(socket_server_t server);
bool            socket_server_begin(socket_server_t server);
socket_client_t socket_server_accept(socket_server_t server); // NULL if none

// Client
socket_client_t socket_client_create(void);
void            socket_client_destroy(socket_client_t client);

bool            socket_client_connect(socket_client_t client, const char* host, uint16_t port);
int32_t         socket_client_available(socket_client_t client);
int32_t         socket_client_read(socket_client_t client, uint8_t* out_buf, int32_t max_len);
int32_t         socket_client_write(socket_client_t client, const uint8_t* buf, int32_t len);
bool            socket_client_connected(socket_client_t client);
void            socket_client_stop(socket_client_t client);

#ifdef __cplusplus
} // extern "C"
#endif