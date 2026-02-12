// SSD1306Bridge.cpp
#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "SSD1306Bridge.h"

static constexpr int16_t SCREEN_W = 128;
static constexpr int16_t SCREEN_H = 64;
static constexpr int8_t OLED_RESET_PIN = -1;

// Vamos manter uma instância por barramento para testar ambos.
static Adafruit_SSD1306 oled0(SCREEN_W, SCREEN_H, &Wire,  OLED_RESET_PIN);
static Adafruit_SSD1306 oled1(SCREEN_W, SCREEN_H, &Wire1, OLED_RESET_PIN);

// Display ativo selecionado em runtime
static Adafruit_SSD1306* g_oled = nullptr;
static TwoWire*          g_wire = nullptr;
static bool              g_inited = false;
static uint8_t           g_addr = 0;

static bool probe_addr(TwoWire& bus, uint8_t addr) {
  bus.beginTransmission(addr);
  return (bus.endTransmission() == 0);
}

static bool try_begin_on_bus(Adafruit_SSD1306& d, TwoWire& bus, uint8_t addr) {
  // 1) Primeiro prova ACK no endereço
  if (!probe_addr(bus, addr)) return false;

  // 2) Tenta iniciar driver
  // periphBegin=false pois já damos begin() no bus manualmente
  if (!d.begin(SSD1306_SWITCHCAPVCC, addr, false, false)) return false;

  d.clearDisplay();
  d.setTextColor(SSD1306_WHITE);
  d.setTextSize(1);
  d.setCursor(0, 0);
  d.print("OLED OK");
  d.display();

  g_oled = &d;
  g_wire = &bus;
  g_inited = true;
  g_addr = addr;
  return true;
}

static void setup_bus(TwoWire& bus) {
  bus.begin();
  bus.setClock(100000);   // 100k para máxima estabilidade inicial
  delay(20);
}

extern "C" {

// Auto: tenta Wire + Wire1, nos endereços 0x3C e 0x3D
uint8_t arduino_ssd1306_begin_auto(void) {
  g_inited = false;
  g_oled = nullptr;
  g_wire = nullptr;
  g_addr = 0;

  // Inicializa ambos barramentos
  setup_bus(Wire);
  setup_bus(Wire1);

  // Ordem de tentativa:
  // Wire: 0x3C -> 0x3D
  if (try_begin_on_bus(oled0, Wire, 0x3C)) return 1;
  if (try_begin_on_bus(oled0, Wire, 0x3D)) return 1;

  // Wire1: 0x3C -> 0x3D
  if (try_begin_on_bus(oled1, Wire1, 0x3C)) return 1;
  if (try_begin_on_bus(oled1, Wire1, 0x3D)) return 1;

  return 0;
}

// Endereço fixo: ainda tenta nos 2 barramentos
uint8_t arduino_ssd1306_begin_addr(uint8_t addr) {
  g_inited = false;
  g_oled = nullptr;
  g_wire = nullptr;
  g_addr = 0;

  setup_bus(Wire);
  setup_bus(Wire1);

  if (try_begin_on_bus(oled0, Wire, addr)) return 1;
  if (try_begin_on_bus(oled1, Wire1, addr)) return 1;

  return 0;
}

void arduino_ssd1306_clear(void) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->clearDisplay();
}

void arduino_ssd1306_display(void) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->display();
}

void arduino_ssd1306_set_text_size(uint8_t size) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->setTextSize(size == 0 ? 1 : size);
}

void arduino_ssd1306_set_cursor_px(int16_t x, int16_t y) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->setCursor(x, y);
}

void arduino_ssd1306_print_cstr(const char* s) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->print(s);
}

void arduino_ssd1306_set_text_color(uint8_t color) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->setTextColor(color);
}

void arduino_ssd1306_draw_pixel(int16_t x, int16_t y, uint8_t color) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->drawPixel(x, y, color);
}

void arduino_ssd1306_draw_line(int16_t x0, int16_t y0, int16_t x1, int16_t y1, uint8_t color) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->drawLine(x0, y0, x1, y1, color);
}

void arduino_ssd1306_draw_rect(int16_t x, int16_t y, int16_t w, int16_t h, uint8_t color) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->drawRect(x, y, w, h, color);
}

void arduino_ssd1306_fill_rect(int16_t x, int16_t y, int16_t w, int16_t h, uint8_t color) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->fillRect(x, y, w, h, color);
}

void arduino_ssd1306_draw_circle(int16_t x, int16_t y, int16_t r, uint8_t color) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->drawCircle(x, y, r, color);
}

void arduino_ssd1306_fill_circle(int16_t x, int16_t y, int16_t r, uint8_t color) {
  if (!g_inited || g_oled == nullptr) return;
  g_oled->fillCircle(x, y, r, color);
}

int16_t arduino_ssd1306_width(void)  { return SCREEN_W; }
int16_t arduino_ssd1306_height(void) { return SCREEN_H; }

} // extern "C"