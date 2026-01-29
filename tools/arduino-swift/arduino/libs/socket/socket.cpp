// ============================================================
// ArduinoSwift - Socket Library (TCP) C ABI Bridge
// File: arduino/libs/socket/socket.cpp
// ============================================================
#include "socket.h"

#include <WiFi.h>

struct AS_SocketServer {
  WiFiServer server;
  bool begun;
  explicit AS_SocketServer(uint16_t port) : server(port), begun(false) {}
};

struct AS_SocketClient {
  WiFiClient client;
};

socket_server_t socket_server_create(uint16_t port) {
  return (socket_server_t)(new AS_SocketServer(port));
}

void socket_server_destroy(socket_server_t server) {
  if (!server) return;
  delete (AS_SocketServer*)server;
}

bool socket_server_begin(socket_server_t server) {
  if (!server) return false;
  AS_SocketServer* s = (AS_SocketServer*)server;
  if (!s->begun) {
    s->server.begin();
    s->begun = true;
  }
  return true;
}

socket_client_t socket_server_accept(socket_server_t server) {
  if (!server) return nullptr;
  AS_SocketServer* s = (AS_SocketServer*)server;
  if (!s->begun) {
    s->server.begin();
    s->begun = true;
  }

  WiFiClient c = s->server.available();
  if (!c) return nullptr;

  AS_SocketClient* out = new AS_SocketClient();
  out->client = c;
  return (socket_client_t)out;
}

socket_client_t socket_client_create(void) {
  return (socket_client_t)(new AS_SocketClient());
}

void socket_client_destroy(socket_client_t client) {
  if (!client) return;
  AS_SocketClient* c = (AS_SocketClient*)client;
  c->client.stop();
  delete c;
}

bool socket_client_connect(socket_client_t client, const char* host, uint16_t port) {
  if (!client || !host || host[0] == 0) return false;
  AS_SocketClient* c = (AS_SocketClient*)client;
  return c->client.connect(host, port);
}

int32_t socket_client_available(socket_client_t client) {
  if (!client) return 0;
  AS_SocketClient* c = (AS_SocketClient*)client;
  return (int32_t)c->client.available();
}

int32_t socket_client_read(socket_client_t client, uint8_t* out_buf, int32_t max_len) {
  if (!client || !out_buf || max_len <= 0) return 0;
  AS_SocketClient* c = (AS_SocketClient*)client;
  return (int32_t)c->client.read(out_buf, (size_t)max_len);
}

int32_t socket_client_write(socket_client_t client, const uint8_t* buf, int32_t len) {
  if (!client || !buf || len <= 0) return 0;
  AS_SocketClient* c = (AS_SocketClient*)client;
  return (int32_t)c->client.write(buf, (size_t)len);
}

bool socket_client_connected(socket_client_t client) {
  if (!client) return false;
  AS_SocketClient* c = (AS_SocketClient*)client;
  return c->client.connected();
}

void socket_client_stop(socket_client_t client) {
  if (!client) return;
  AS_SocketClient* c = (AS_SocketClient*)client;
  c->client.stop();
}