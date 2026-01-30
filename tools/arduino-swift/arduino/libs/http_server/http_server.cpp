// http_server.cpp
#include <Arduino.h>
#include <WiFiS3.h>
#include "http_server.h"

// Mantém objetos estáticos simples.
// (Evita malloc/new e problemas de lifetime.)

static WiFiServer* g_server = nullptr;
static WiFiClient  g_client;
static uint16_t    g_port   = 0;

static inline bool clientValid() {
  // WiFiClient tem operator bool() em alguns cores; garantimos pelos dois jeitos:
  // connected() sozinho às vezes é true mesmo se o objeto estiver "vazio" dependendo do core,
  // então fazemos as duas checagens.
  return (bool)g_client && g_client.connected();
}

extern "C" int32_t arduino_http_server_begin(uint16_t port) {
  // Se já estava rodando, reinicia no novo port (idempotente).
  arduino_http_server_end();

  g_port = port;

  // IMPORTANTE: WiFiServer na lib do UNO R4 WiFi normalmente precisa existir como objeto.
  // Aqui usamos new só para permitir port dinâmico.
  // Se preferir zero-new, você fixa port=80 e usa "static WiFiServer server(80)".
  g_server = new WiFiServer((uint16_t)g_port);
  if (!g_server) {
    return 0;
  }

  // begin() não retorna bool nessa lib; assumimos ok se objeto existe.
  g_server->begin();

  // Dá uma limpada no client anterior.
  g_client.stop();

  return 1;
}

extern "C" void arduino_http_server_end(void) {
  // Para client primeiro.
  if ((bool)g_client) {
    g_client.stop();
  }

  if (g_server) {
    // WiFiServer não tem end() consistente em todas libs; delete é suficiente aqui.
    delete g_server;
    g_server = nullptr;
  }

  g_port = 0;
}

extern "C" int32_t arduino_http_server_client_available(void) {
  if (!g_server) return 0;

  // Se já temos um client conectado, não pega outro.
  if (clientValid()) return 1;

  // Pega um novo client, se houver.
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

extern "C" int32_t arduino_http_server_client_read(uint8_t* out, uint32_t cap) {
  if (!clientValid()) return 0;
  if (!out || cap == 0) return 0;

  // read(buf, size) retorna int (bytes lidos) ou -1.
  int n = g_client.read(out, (size_t)cap);
  if (n < 0) return 0;
  return (int32_t)n;
}

extern "C" int32_t arduino_http_server_client_write(const uint8_t* data, uint32_t len) {
  if (!clientValid()) return 0;
  if (!data || len == 0) return 0;

  // write(buf, size) retorna size_t
  size_t w = g_client.write((const uint8_t*)data, (size_t)len);
  return (int32_t)w;
}

extern "C" void arduino_http_server_client_stop(void) {
  if ((bool)g_client) {
    g_client.stop();
  }
}