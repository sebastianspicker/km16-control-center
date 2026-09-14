#ifndef KM16_UART_FRAME_H
#define KM16_UART_FRAME_H

#include <stddef.h>
#include <stdint.h>

#define KM16_UART_FRAME_HEADER 0x55u
#define KM16_UART_BODY_MAX 255u
#define KM16_UART_FRAME_MAX (KM16_UART_BODY_MAX + 2u)

/* Returns body_length + 2 on success, zero for invalid inputs/bounds. */
size_t km16_uart_build_frame(
    const uint8_t *body,
    size_t body_length,
    uint8_t *output,
    size_t output_capacity);

#endif
