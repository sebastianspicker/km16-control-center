#ifndef KM16_ENCODER_H
#define KM16_ENCODER_H

#include <stdint.h>

typedef struct {
    uint8_t gray_state;
    int32_t signed_steps;
} km16_encoder_state_t;

void km16_encoder_init(km16_encoder_state_t *state, uint8_t phase0, uint8_t phase1);

/* Phase 0 is state bit 0 and phase 1 is bit 1, matching the recovered decoder. */
/* Returns the signed Gray-state transition: -1, 0, or +1. */
int8_t km16_encoder_update(km16_encoder_state_t *state, uint8_t phase0, uint8_t phase1);

#endif
