// SSD1306Bridge.h
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void arduino_ssd1306_begin(uint8_t i2c_addr);
void arduino_ssd1306_set_font_system5x7(void);
void arduino_ssd1306_clear(void);
void arduino_ssd1306_set_cursor(uint8_t col, uint8_t row);
void arduino_ssd1306_print_cstr(const char* s);

#ifdef __cplusplus
}
#endif