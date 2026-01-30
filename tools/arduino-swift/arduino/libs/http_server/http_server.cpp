// http_server.cpp
#include <Arduino.h>
#include <WiFiS3.h>
#include "http_server.h"

static WiFiServer* g_server = nullptr;
static WiFiClient  g_client;
static uint16_t    g_port   = 0;

static inline bool clientValid() {
  return (bool)g_client && g_client.connected();
}

extern "C" int32_t arduino_http_server_begin(uint16_t port) {
  arduino_http_server_end();

  g_port = port;

  g_server = new WiFiServer((uint16_t)g_port);
  if (!g_server) return 0;

  g_server->begin();
  g_client.stop();

  return 1;
}

extern "C" void arduino_http_server_end(void) {
  if ((bool)g_client) {
    g_client.stop();
  }

  if (g_server) {
    delete g_server;
    g_server = nullptr;
  }

  g_port = 0;
}

extern "C" int32_t arduino_http_server_client_available(void) {
  if (!g_server) return 0;

  if (clientValid()) return 1;

  WiFiClient c = g_server->available();
  if ((bool)c) {
    g_client = c;
    return clientValid() ? 1 : 0;
  }

  return 0;
}

extern "C" int32_t arduino_http_server_client_connected(void) {
  return clientValid() ? 1 : 0;
}

extern "C" int32_t arduino_http_server_client_available_bytes(void) {
  if (!clientValid()) return 0;
  return (int32_t)g_client.available();
}

extern "C" int32_t arduino_http_server_client_read(uint8_t* out, uint32_t cap) {
  if (!clientValid()) return 0;
  if (!out || cap == 0) return 0;

  int n = g_client.read(out, (size_t)cap);
  if (n < 0) return 0;
  return (int32_t)n;
}

extern "C" int32_t arduino_http_server_client_write(const uint8_t* data, uint32_t len) {
  if (!clientValid()) return 0;
  if (!data || len == 0) return 0;

  size_t w = g_client.write((const uint8_t*)data, (size_t)len);
  return (int32_t)w;
}

extern "C" void arduino_http_server_client_stop(void) {
  if ((bool)g_client) {
    g_client.stop();
  }
}