#ifndef KM16_LED_PWM_H
#define KM16_LED_PWM_H

#include <stddef.h>
#include <stdint.h>

#include "km16/board_profile.h"

#define KM16_LED_BITS_PER_PIXEL 24u
#define KM16_LED_RESET_CELLS 170u
#define KM16_LED_PWM_ZERO_COMPARE 9u
#define KM16_LED_PWM_ONE_COMPARE 30u
#define KM16_LED_PWM_BUFFER_CELLS \
    ((KM16_LED_COUNT * KM16_LED_BITS_PER_PIXEL) + KM16_LED_RESET_CELLS)

typedef struct {
    uint8_t red;
    uint8_t green;
    uint8_t blue;
} km16_rgb_t;

/* Returns KM16_LED_PWM_BUFFER_CELLS on success, zero for invalid inputs/bounds. */
size_t km16_led_encode_pwm(
    const km16_rgb_t *pixels,
    size_t pixel_count,
    uint8_t *output,
    size_t output_capacity);

#endif
