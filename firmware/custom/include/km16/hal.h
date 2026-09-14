#ifndef KM16_HAL_H
#define KM16_HAL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "km16/board_profile.h"

/*
 * Future hardware boundary. No implementation in this scaffold accesses GPIO,
 * timers, DMA, UART, USB, flash, radio hardware, or a physical board. A future
 * STM32F1-compatible port must preserve SWD unless disabling it is separately
 * justified and verified.
 */
typedef struct {
    void *context;
    uint32_t (*millis)(void *context);
    bool (*scan_matrix)(void *context, uint8_t rows[KM16_MATRIX_ROWS]);
    bool (*read_encoder)(void *context, uint8_t index, uint8_t *phase0, uint8_t *phase1);
    bool (*submit_led_pwm)(void *context, const uint8_t *cells, size_t cell_count);
    bool (*write_uart)(void *context, const uint8_t *bytes, size_t byte_count);
} km16_hal_t;

#endif
