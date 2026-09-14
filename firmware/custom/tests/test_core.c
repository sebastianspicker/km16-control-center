#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "km16/board_profile.h"
#include "km16/debounce.h"
#include "km16/encoder.h"
#include "km16/led_pwm.h"
#include "km16/uart_frame.h"

static unsigned failures;

#define CHECK(expression) do { \
    if (!(expression)) { \
        fprintf(stderr, "%s:%d: check failed: %s\n", __FILE__, __LINE__, #expression); \
        ++failures; \
    } \
} while (false)

static void test_board_profile(void)
{
    CHECK(KM16_MATRIX_ROWS == 4u);
    CHECK(KM16_MATRIX_COLUMNS == 6u);
    CHECK(km16_matrix_columns[1].port == KM16_PORT_C);
    CHECK(km16_matrix_columns[1].number == 13u);
    CHECK(km16_encoder_pins[2].phase0.number == 14u);
    CHECK(km16_encoder_pins[2].phase1.number == 15u);
    CHECK(km16_encoder_press_coordinates[0].row == 0u);
    CHECK(km16_encoder_press_coordinates[0].column == 4u);
    CHECK(km16_encoder_press_coordinates[2].row == 2u);
    CHECK(km16_encoder_press_coordinates[2].column == 5u);
    CHECK(km16_led_pwm_pin.port == KM16_PORT_B);
    CHECK(km16_led_pwm_pin.number == 8u);
    CHECK(km16_uart_tx_pin.number == 9u);
    CHECK(km16_uart_rx_pin.number == 10u);
    CHECK(km16_matrix_led_index[0][0] == 12u);
    CHECK(km16_matrix_led_index[3][3] == 0u);
    CHECK(km16_matrix_led_index[0][4] == KM16_LED_NONE);
    CHECK(km16_led_groups[15] == KM16_LED_GROUP_KEYLIGHT);
    CHECK(km16_led_groups[16] == KM16_LED_GROUP_LAYER_STATUS);
    CHECK(km16_led_groups[21] == KM16_LED_GROUP_UNDERGLOW);
}

static void test_debounce_and_wrap(void)
{
    const uint8_t released[KM16_MATRIX_ROWS] = {0u, 0u, 0u, 0u};
    const uint8_t pressed[KM16_MATRIX_ROWS] = {1u, 0u, 0u, 0u};
    const uint8_t masked[KM16_MATRIX_ROWS] = {0xc2u, 0u, 0u, 0u};
    km16_matrix_debounce_t state;

    km16_matrix_debounce_init(&state, released, UINT32_MAX - 2u);
    CHECK(!km16_matrix_debounce_update(&state, pressed, UINT32_MAX - 2u));
    CHECK(!km16_matrix_debounce_update(&state, pressed, 2u));
    CHECK(km16_matrix_debounce_update(&state, pressed, 3u));
    CHECK(state.stable[0] == 1u);
    CHECK(!state.pending);

    CHECK(!km16_matrix_debounce_update(&state, released, 10u));
    CHECK(!km16_matrix_debounce_update(&state, pressed, 12u));
    CHECK(!state.pending);

    CHECK(!km16_matrix_debounce_update(&state, masked, 20u));
    CHECK(!km16_matrix_debounce_update(&state, masked, 25u));
    CHECK(km16_matrix_debounce_update(&state, masked, 26u));
    CHECK(state.stable[0] == 2u);
}

static void test_encoder(void)
{
    const uint8_t negative_cycle[4][2] = {{1u, 0u}, {1u, 1u}, {0u, 1u}, {0u, 0u}};
    const uint8_t positive_cycle[4][2] = {{0u, 1u}, {1u, 1u}, {1u, 0u}, {0u, 0u}};
    km16_encoder_state_t state;
    size_t index;

    km16_encoder_init(&state, 0u, 0u);
    for (index = 0u; index < 4u; ++index) {
        CHECK(km16_encoder_update(&state, negative_cycle[index][0], negative_cycle[index][1]) == -1);
    }
    CHECK(state.signed_steps == -4);
    for (index = 0u; index < 4u; ++index) {
        CHECK(km16_encoder_update(&state, positive_cycle[index][0], positive_cycle[index][1]) == 1);
    }
    CHECK(state.signed_steps == 0);
    CHECK(km16_encoder_update(&state, 1u, 1u) == 0);

    state.signed_steps = INT32_MAX;
    state.gray_state = 0u;
    CHECK(km16_encoder_update(&state, 0u, 1u) == 1);
    CHECK(state.signed_steps == INT32_MAX);

    state.signed_steps = INT32_MIN;
    state.gray_state = 0u;
    CHECK(km16_encoder_update(&state, 1u, 0u) == -1);
    CHECK(state.signed_steps == INT32_MIN);

    /* A corrupt state byte must not index outside the 16-entry table. */
    state.signed_steps = 0;
    state.gray_state = UINT8_MAX;
    CHECK(km16_encoder_update(&state, 0u, 0u) == 0);
    CHECK(state.gray_state == 0u);
}

static void test_led_pwm(void)
{
    km16_rgb_t pixels[KM16_LED_COUNT] = {{0u, 0u, 0u}};
    uint8_t output[KM16_LED_PWM_BUFFER_CELLS];
    size_t index;

    pixels[0].red = 0x80u;
    pixels[0].green = 0x01u;
    CHECK(KM16_LED_PWM_BUFFER_CELLS == 818u);
    CHECK(km16_led_encode_pwm(pixels, KM16_LED_COUNT, output, sizeof(output) - 1u) == 0u);
    CHECK(km16_led_encode_pwm(pixels, KM16_LED_COUNT - 1u, output, sizeof(output)) == 0u);
    CHECK(km16_led_encode_pwm(pixels, KM16_LED_COUNT, output, sizeof(output)) == sizeof(output));
    for (index = 0u; index < 7u; ++index) {
        CHECK(output[index] == KM16_LED_PWM_ZERO_COMPARE);
    }
    CHECK(output[7] == KM16_LED_PWM_ONE_COMPARE);
    CHECK(output[8] == KM16_LED_PWM_ONE_COMPARE);
    CHECK(output[9] == KM16_LED_PWM_ZERO_COMPARE);
    CHECK(output[KM16_LED_COUNT * KM16_LED_BITS_PER_PIXEL - 1u] == KM16_LED_PWM_ZERO_COMPARE);
    for (index = KM16_LED_COUNT * KM16_LED_BITS_PER_PIXEL;
         index < KM16_LED_PWM_BUFFER_CELLS; ++index) {
        CHECK(output[index] == 0u);
    }
}

static void test_uart_frame(void)
{
    const uint8_t body[3] = {0u, 4u, 1u};
    uint8_t large_body[KM16_UART_BODY_MAX];
    uint8_t frame[KM16_UART_FRAME_MAX];
    size_t index;

    CHECK(km16_uart_build_frame(body, sizeof(body), frame, 4u) == 0u);
    CHECK(km16_uart_build_frame(body, sizeof(body), frame, sizeof(frame)) == 5u);
    CHECK(frame[0] == 0x55u);
    CHECK(frame[1] == 3u);
    CHECK(frame[4] == 1u);
    CHECK(km16_uart_build_frame(NULL, 0u, frame, sizeof(frame)) == 2u);
    CHECK(frame[1] == 0u);
    CHECK(km16_uart_build_frame(NULL, 1u, frame, sizeof(frame)) == 0u);

    for (index = 0u; index < sizeof(large_body); ++index) {
        large_body[index] = (uint8_t)index;
    }
    CHECK(km16_uart_build_frame(large_body, sizeof(large_body), frame, sizeof(frame)) == sizeof(frame));
    CHECK(frame[1] == 255u);
    CHECK(frame[256] == 254u);
    CHECK(km16_uart_build_frame(large_body, 256u, frame, sizeof(frame)) == 0u);
}

int main(void)
{
    test_board_profile();
    test_debounce_and_wrap();
    test_encoder();
    test_led_pwm();
    test_uart_frame();
    if (failures != 0u) {
        fprintf(stderr, "%u checks failed\n", failures);
        return 1;
    }
    puts("all km16 portable-core checks passed");
    return 0;
}
