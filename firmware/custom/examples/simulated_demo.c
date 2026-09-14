#include <inttypes.h>
#include <stdio.h>

#include "km16/debounce.h"
#include "km16/encoder.h"
#include "km16/led_pwm.h"
#include "km16/uart_frame.h"

int main(void)
{
    const uint8_t released[KM16_MATRIX_ROWS] = {0u, 0u, 0u, 0u};
    const uint8_t pressed[KM16_MATRIX_ROWS] = {1u, 0u, 0u, 0u};
    const uint8_t body[3] = {0u, 2u, 1u};
    const uint8_t gray_cycle[4][2] = {{1u, 0u}, {1u, 1u}, {0u, 1u}, {0u, 0u}};
    km16_matrix_debounce_t debounce;
    km16_encoder_state_t encoder;
    km16_rgb_t pixels[KM16_LED_COUNT] = {{0u, 0u, 0u}};
    uint8_t pwm[KM16_LED_PWM_BUFFER_CELLS];
    uint8_t frame[KM16_UART_FRAME_MAX];
    size_t index;
    size_t frame_length;
    size_t pwm_length;

    km16_matrix_debounce_init(&debounce, released, 100u);
    (void)km16_matrix_debounce_update(&debounce, pressed, 101u);
    (void)km16_matrix_debounce_update(&debounce, pressed, 107u);

    km16_encoder_init(&encoder, 0u, 0u);
    for (index = 0u; index < 4u; ++index) {
        (void)km16_encoder_update(&encoder, gray_cycle[index][0], gray_cycle[index][1]);
    }

    pixels[0].red = 0x80u;
    pixels[0].green = 0x01u;
    pwm_length = km16_led_encode_pwm(pixels, KM16_LED_COUNT, pwm, sizeof(pwm));
    frame_length = km16_uart_build_frame(body, sizeof(body), frame, sizeof(frame));

    printf("debounced row0 mask: 0x%02x\n", debounce.stable[0]);
    printf("signed Gray transitions: %" PRId32 "\n", encoder.signed_steps);
    printf("LED compare cells: %zu (first=%u, eighth=%u, ninth=%u)\n",
           pwm_length, pwm[0], pwm[7], pwm[8]);
    printf("UART frame: %02x %02x %02x %02x %02x\n",
           frame[0], frame[1], frame[2], frame[3], frame[4]);

    return ((debounce.stable[0] == 1u) && (encoder.signed_steps == -4) &&
            (pwm_length == KM16_LED_PWM_BUFFER_CELLS) && (frame_length == 5u)) ? 0 : 1;
}
