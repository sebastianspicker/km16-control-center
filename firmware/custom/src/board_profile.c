#include "km16/board_profile.h"

const km16_pin_t km16_matrix_rows[KM16_MATRIX_ROWS] = {
    {KM16_PORT_A, 0u}, {KM16_PORT_A, 1u}, {KM16_PORT_A, 2u}, {KM16_PORT_A, 3u}
};

const km16_pin_t km16_matrix_columns[KM16_MATRIX_COLUMNS] = {
    {KM16_PORT_B, 0u}, {KM16_PORT_C, 13u}, {KM16_PORT_B, 2u},
    {KM16_PORT_B, 10u}, {KM16_PORT_B, 11u}, {KM16_PORT_B, 12u}
};

const km16_encoder_pins_t km16_encoder_pins[KM16_ENCODER_COUNT] = {
    {{KM16_PORT_B, 5u}, {KM16_PORT_B, 4u}},
    {{KM16_PORT_A, 6u}, {KM16_PORT_A, 7u}},
    {{KM16_PORT_C, 14u}, {KM16_PORT_C, 15u}}
};

const km16_matrix_coordinate_t km16_encoder_press_coordinates[KM16_ENCODER_COUNT] = {
    {0u, 4u}, {0u, 5u}, {2u, 5u}
};

const km16_pin_t km16_led_pwm_pin = {KM16_PORT_B, 8u};
const km16_pin_t km16_led_enable_pin = {KM16_PORT_B, 7u};
const km16_pin_t km16_uart_tx_pin = {KM16_PORT_A, 9u};
const km16_pin_t km16_uart_rx_pin = {KM16_PORT_A, 10u};
const km16_pin_t km16_wired_presence_input_pin = {KM16_PORT_B, 9u};
const km16_pin_t km16_auxiliary_control_pin = {KM16_PORT_A, 8u};

const uint8_t km16_matrix_led_index[KM16_MATRIX_ROWS][KM16_MATRIX_COLUMNS] = {
    {12u, 13u, 14u, 15u, KM16_LED_NONE, KM16_LED_NONE},
    {11u, 10u, 9u, 8u, KM16_LED_NONE, KM16_LED_NONE},
    {4u, 5u, 6u, 7u, KM16_LED_NONE, KM16_LED_NONE},
    {3u, 2u, 1u, 0u, KM16_LED_NONE, KM16_LED_NONE}
};

const km16_led_position_t km16_led_positions[KM16_LED_COUNT] = {
    {224u, 64u}, {149u, 64u}, {75u, 64u}, {0u, 64u},
    {0u, 42u}, {75u, 42u}, {149u, 42u}, {224u, 42u},
    {224u, 21u}, {149u, 21u}, {75u, 21u}, {0u, 21u},
    {0u, 0u}, {75u, 0u}, {149u, 0u}, {224u, 0u},
    {0u, 0u}, {0u, 0u}, {0u, 0u}, {0u, 0u}, {0u, 0u},
    {0u, 0u}, {0u, 0u}, {0u, 0u}, {0u, 0u}, {0u, 0u}, {0u, 0u}
};

const km16_led_group_t km16_led_groups[KM16_LED_COUNT] = {
    KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT,
    KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT,
    KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT,
    KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT,
    KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT, KM16_LED_GROUP_KEYLIGHT,
    KM16_LED_GROUP_KEYLIGHT,
    KM16_LED_GROUP_LAYER_STATUS, KM16_LED_GROUP_LAYER_STATUS,
    KM16_LED_GROUP_LAYER_STATUS, KM16_LED_GROUP_LAYER_STATUS,
    KM16_LED_GROUP_LAYER_STATUS,
    KM16_LED_GROUP_UNDERGLOW, KM16_LED_GROUP_UNDERGLOW, KM16_LED_GROUP_UNDERGLOW,
    KM16_LED_GROUP_UNDERGLOW, KM16_LED_GROUP_UNDERGLOW, KM16_LED_GROUP_UNDERGLOW
};
