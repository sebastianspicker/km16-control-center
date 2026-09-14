#include "km16/debounce.h"

#include <stddef.h>

static void copy_rows(uint8_t destination[KM16_MATRIX_ROWS], const uint8_t source[KM16_MATRIX_ROWS])
{
    uint8_t row;
    for (row = 0u; row < KM16_MATRIX_ROWS; ++row) {
        destination[row] = (uint8_t)(source[row] & KM16_MATRIX_COLUMN_MASK);
    }
}

static bool rows_equal(const uint8_t left[KM16_MATRIX_ROWS], const uint8_t right[KM16_MATRIX_ROWS])
{
    uint8_t row;
    for (row = 0u; row < KM16_MATRIX_ROWS; ++row) {
        if (left[row] != (uint8_t)(right[row] & KM16_MATRIX_COLUMN_MASK)) {
            return false;
        }
    }
    return true;
}

void km16_matrix_debounce_init(
    km16_matrix_debounce_t *state,
    const uint8_t initial[KM16_MATRIX_ROWS],
    uint32_t now_ms)
{
    if ((state == NULL) || (initial == NULL)) {
        return;
    }
    copy_rows(state->stable, initial);
    copy_rows(state->candidate, initial);
    state->candidate_since_ms = now_ms;
    state->pending = false;
}

bool km16_matrix_debounce_update(
    km16_matrix_debounce_t *state,
    const uint8_t raw[KM16_MATRIX_ROWS],
    uint32_t now_ms)
{
    if ((state == NULL) || (raw == NULL)) {
        return false;
    }

    if (!rows_equal(state->candidate, raw)) {
        copy_rows(state->candidate, raw);
        state->candidate_since_ms = now_ms;
        state->pending = !rows_equal(state->stable, state->candidate);
        return false;
    }

    if (state->pending &&
        ((uint32_t)(now_ms - state->candidate_since_ms) > KM16_DEBOUNCE_THRESHOLD_MS)) {
        copy_rows(state->stable, state->candidate);
        state->pending = false;
        return true;
    }
    return false;
}
