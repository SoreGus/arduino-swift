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

}