#ifndef KM16_BOARD_PROFILE_H
#define KM16_BOARD_PROFILE_H

#include <stdint.h>

#define KM16_MATRIX_ROWS 4u
#define KM16_MATRIX_COLUMNS 6u
#define KM16_ENCODER_COUNT 3u
#define KM16_LED_COUNT 27u
#define KM16_KEY_LED_COUNT 16u
#define KM16_STATUS_LED_FIRST 16u
#define KM16_STATUS_LED_COUNT 5u
#define KM16_UNDERGLOW_LED_FIRST 21u
#define KM16_UNDERGLOW_LED_COUNT 6u
#define KM16_LED_NONE UINT8_MAX

typedef enum {
    KM16_PORT_A,
    KM16_PORT_B,
    KM16_PORT_C
} km16_port_t;

typedef struct {
    km16_port_t port;
    uint8_t number;
} km16_pin_t;

typedef struct {
    km16_pin_t phase0;
    km16_pin_t phase1;
} km16_encoder_pins_t;

typedef struct {
    uint8_t x;
    uint8_t y;
} km16_led_position_t;

typedef struct {
    uint8_t row;
    uint8_t column;
} km16_matrix_coordinate_t;

typedef enum {
    KM16_LED_GROUP_KEYLIGHT,
    KM16_LED_GROUP_LAYER_STATUS,
    KM16_LED_GROUP_UNDERGLOW
} km16_led_group_t;

extern const km16_pin_t km16_matrix_rows[KM16_MATRIX_ROWS];
extern const km16_pin_t km16_matrix_columns[KM16_MATRIX_COLUMNS];
extern const km16_encoder_pins_t km16_encoder_pins[KM16_ENCODER_COUNT];
extern const km16_matrix_coordinate_t km16_encoder_press_coordinates[KM16_ENCODER_COUNT];
extern const km16_pin_t km16_led_pwm_pin;
extern const km16_pin_t km16_led_enable_pin;
extern const km16_pin_t km16_uart_tx_pin;
extern const km16_pin_t km16_uart_rx_pin;
extern const km16_pin_t km16_wired_presence_input_pin;
extern const km16_pin_t km16_auxiliary_control_pin;
extern const uint8_t km16_matrix_led_index[KM16_MATRIX_ROWS][KM16_MATRIX_COLUMNS];
extern const km16_led_position_t km16_led_positions[KM16_LED_COUNT];
extern const km16_led_group_t km16_led_groups[KM16_LED_COUNT];

#endif
