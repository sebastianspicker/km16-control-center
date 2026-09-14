#include "km16/uart_frame.h"

#include <stddef.h>

size_t km16_uart_build_frame(
    const uint8_t *body,
    size_t body_length,
    uint8_t *output,
    size_t output_capacity)
{
    size_t index;
    size_t frame_length;

    if ((output == NULL) || (body_length > KM16_UART_BODY_MAX) ||
        ((body_length != 0u) && (body == NULL))) {
        return 0u;
    }
    frame_length = body_length + 2u;
    if (output_capacity < frame_length) {
        return 0u;
    }

    output[0] = KM16_UART_FRAME_HEADER;
    output[1] = (uint8_t)body_length;
    for (index = 0u; index < body_length; ++index) {
        output[index + 2u] = body[index];
    }
    return frame_length;
}
