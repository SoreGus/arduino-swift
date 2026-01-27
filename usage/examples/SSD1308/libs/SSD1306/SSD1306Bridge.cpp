// SSD1306Bridge.cpp
#include <Arduino.h>
#include <Wire.h>

#include <SSD1306Ascii.h>
#include <SSD1306AsciiWire.h>

#include "SSD1306Bridge.h"

static SSD1306AsciiWire oled;

extern "C" {

void arduino_ssd1306_begin(uint8_t i2c_addr) {
  Wire.begin();

  // UNO R4 (Renesas): timeout padrão pode abortar transações longas e causar “pixels aleatórios”
  // Aumente para 10ms (ou mais, se necessário).
#if defined(ARDUINO_ARCH_RENESAS)
  Wire.setWireTimeout(10000);     // 10ms
  Wire.setClock(100000);          // 100kHz (bem mais estável com level shifter)
  delay(10);                      // dá tempo do OLED estabilizar após power-on/reset
#endif

  oled.begin(&Adafruit128x64, i2c_addr);
  oled.clear();
}

void arduino_ssd1306_set_font_system5x7(void) {
  oled.setFont(System5x7);
}

void arduino_ssd1306_clear(void) {
  oled.clear();
}

void arduino_ssd1306_set_cursor(uint8_t col, uint8_t row) {
  oled.setCursor(col, row);
}

void arduino_ssd1306_print_cstr(const char* s) {
  oled.print(s);
}

} // extern "C"