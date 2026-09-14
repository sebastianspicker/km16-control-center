#include "km16/led_pwm.h"

#include <stddef.h>

static size_t encode_channel(uint8_t value, uint8_t *output, size_t offset)
{
    uint8_t mask;
    for (mask = 0x80u; mask != 0u; mask >>= 1u) {
        output[offset++] = ((value & mask) != 0u)
            ? KM16_LED_PWM_ONE_COMPARE
            : KM16_LED_PWM_ZERO_COMPARE;
    }
    return offset;
}

size_t km16_led_encode_pwm(
    const km16_rgb_t *pixels,
    size_t pixel_count,
    uint8_t *output,
    size_t output_capacity)
{
    size_t index;
    size_t offset = 0u;

    if ((pixels == NULL) || (output == NULL) ||
        (pixel_count != KM16_LED_COUNT) ||
        (output_capacity < KM16_LED_PWM_BUFFER_CELLS)) {
        return 0u;
    }

    for (index = 0u; index < pixel_count; ++index) {
        offset = encode_channel(pixels[index].green, output, offset);
        offset = encode_channel(pixels[index].red, output, offset);
        offset = encode_channel(pixels[index].blue, output, offset);
    }
    while (offset < KM16_LED_PWM_BUFFER_CELLS) {
        output[offset++] = 0u;
    }
    return offset;
}
