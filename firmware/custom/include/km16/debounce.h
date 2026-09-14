#ifndef KM16_DEBOUNCE_H
#define KM16_DEBOUNCE_H

#include <stdbool.h>
#include <stdint.h>

#include "km16/board_profile.h"

#define KM16_DEBOUNCE_THRESHOLD_MS 5u
#define KM16_MATRIX_COLUMN_MASK ((uint8_t)((1u << KM16_MATRIX_COLUMNS) - 1u))

typedef struct {
    uint8_t stable[KM16_MATRIX_ROWS];
    uint8_t candidate[KM16_MATRIX_ROWS];
    uint32_t candidate_since_ms;
    bool pending;
} km16_matrix_debounce_t;

void km16_matrix_debounce_init(
    km16_matrix_debounce_t *state,
    const uint8_t initial[KM16_MATRIX_ROWS],
    uint32_t now_ms);

bool km16_matrix_debounce_update(
    km16_matrix_debounce_t *state,
    const uint8_t raw[KM16_MATRIX_ROWS],
    uint32_t now_ms);

#endif
