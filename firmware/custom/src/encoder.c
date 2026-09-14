#include "km16/encoder.h"

#include <limits.h>
#include <stddef.h>

static const int8_t gray_transitions[16] = {
    0, -1, 1, 0,
    1, 0, 0, -1,
    -1, 0, 0, 1,
    0, 1, -1, 0
};

static uint8_t gray_value(uint8_t phase0, uint8_t phase1)
{
    return (uint8_t)(((phase0 != 0u) ? 1u : 0u) | ((phase1 != 0u) ? 2u : 0u));
}

void km16_encoder_init(km16_encoder_state_t *state, uint8_t phase0, uint8_t phase1)
{
    if (state == NULL) {
        return;
    }
    state->gray_state = gray_value(phase0, phase1);
    state->signed_steps = 0;
}

int8_t km16_encoder_update(km16_encoder_state_t *state, uint8_t phase0, uint8_t phase1)
{
    uint8_t current;
    int8_t step;

    if (state == NULL) {
        return 0;
    }
    current = gray_value(phase0, phase1);
    step = gray_transitions[(uint8_t)(((state->gray_state & 3u) << 2u) | current)];
    state->gray_state = current;

    if ((step > 0) && (state->signed_steps < INT32_MAX)) {
        ++state->signed_steps;
    } else if ((step < 0) && (state->signed_steps > INT32_MIN)) {
        --state->signed_steps;
    }
    return step;
}
