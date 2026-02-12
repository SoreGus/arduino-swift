// SSD1306Bridge.h
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint8_t arduino_ssd1306_begin_auto(void);
uint8_t arduino_ssd1306_begin_addr(uint8_t addr);

void arduino_ssd1306_clear(void);
void arduino_ssd1306_display(void);

void arduino_ssd1306_set_text_size(uint8_t size);
void arduino_ssd1306_set_cursor_px(int16_t x, int16_t y);
void arduino_ssd1306_print_cstr(const char* s);
void arduino_ssd1306_set_text_color(uint8_t color);

void arduino_ssd1306_draw_pixel(int16_t x, int16_t y, uint8_t color);
void arduino_ssd1306_draw_line(int16_t x0, int16_t y0, int16_t x1, int16_t y1, uint8_t color);
void arduino_ssd1306_draw_rect(int16_t x, int16_t y, int16_t w, int16_t h, uint8_t color);
void arduino_ssd1306_fill_rect(int16_t x, int16_t y, int16_t w, int16_t h, uint8_t color);
void arduino_ssd1306_draw_circle(int16_t x, int16_t y, int16_t r, uint8_t color);
void arduino_ssd1306_fill_circle(int16_t x, int16_t y, int16_t r, uint8_t color);

int16_t arduino_ssd1306_width(void);
int16_t arduino_ssd1306_height(void);

#ifdef __cplusplus
}
#endif