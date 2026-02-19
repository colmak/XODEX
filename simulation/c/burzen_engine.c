#include "burzen_engine.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static float average(const float *values, size_t count) {
  if (count == 0) return 0.0f;
  float total = 0.0f;
  for (size_t i = 0; i < count; i++) total += values[i];
  return total / (float)count;
}

static float clamp01(float v) {
  if (v < 0.0f) return 0.0f;
  if (v > 1.0f) return 1.0f;
  return v;
}

void burzen_init(BurzenSoA *soa, size_t cell_count) {
  memset(soa, 0, sizeof(*soa));
  soa->cell_count = cell_count;
  soa->atp_pool = calloc(cell_count, sizeof(float));
  soa->fold_quality = calloc(cell_count, sizeof(float));
  soa->stress_index = calloc(cell_count, sizeof(float));
  soa->flux_state = calloc(cell_count, sizeof(float));
  for (size_t i = 0; i < cell_count; i++) {
    soa->atp_pool[i] = 0.5f;
    soa->fold_quality[i] = 0.7f;
    soa->stress_index[i] = 0.2f;
    soa->flux_state[i] = 0.5f;
  }
}

void burzen_destroy(BurzenSoA *soa) {
  free(soa->atp_pool);
  free(soa->fold_quality);
  free(soa->stress_index);
  free(soa->flux_state);
  memset(soa, 0, sizeof(*soa));
}

EigenstateDelta burzen_step(BurzenSoA *soa, float dt) {
  EigenstateDelta delta = {0};
  for (size_t i = 0; i < soa->cell_count; i++) {
    float atp = soa->atp_pool[i] + (0.08f - soa->stress_index[i] * 0.05f) * dt;
    float fold = soa->fold_quality[i] + (atp - 0.5f) * 0.03f * dt;
    float stress = soa->stress_index[i] + (0.25f - fold) * 0.04f * dt;
    float flux = soa->flux_state[i] + (atp - stress) * 0.05f * dt;

    soa->atp_pool[i] = clamp01(atp);
    soa->fold_quality[i] = clamp01(fold);
    soa->stress_index[i] = clamp01(stress);
    soa->flux_state[i] = clamp01(flux);
  }

  delta.atp_eigenstate = average(soa->atp_pool, soa->cell_count);
  delta.fold_eigen_delta = average(soa->fold_quality, soa->cell_count);
  delta.metabolic_eigen_delta = average(soa->flux_state, soa->cell_count);
  delta.stress_eigen_delta = average(soa->stress_index, soa->cell_count);
  delta.lysosome_pruning_delta = 1.0f - delta.stress_eigen_delta;
  return delta;
}

Eigenstate burzen_export_eigenstate(const BurzenSoA *soa) {
  Eigenstate eigen = {0};
  eigen.energy_setpoint = average(soa->atp_pool, soa->cell_count);
  eigen.epigenetic_profile = average(soa->fold_quality, soa->cell_count);
  eigen.cascade_readiness = average(soa->flux_state, soa->cell_count);
  eigen.stress_resilience = 1.0f - average(soa->stress_index, soa->cell_count);
  eigen.differentiation_axis = eigen.epigenetic_profile - eigen.stress_resilience;
  eigen.mechanical_state = (eigen.energy_setpoint + eigen.cascade_readiness) * 0.5f;
  return eigen;
}

static uint32_t fnv1a_checksum(const char *payload) {
  uint32_t hash = 2166136261u;
  for (size_t i = 0; payload[i] != '\0'; i++) {
    hash ^= (uint8_t)payload[i];
    hash *= 16777619u;
  }
  return hash;
}

int codex_encode_eigenstate(Eigenstate eigen, char *buffer, size_t buffer_size) {
  char payload[196];
  int payload_len = snprintf(payload, sizeof(payload),
                             "%08x%08x%08x%08x%08x%08x",
                             *(uint32_t *)&eigen.energy_setpoint,
                             *(uint32_t *)&eigen.epigenetic_profile,
                             *(uint32_t *)&eigen.cascade_readiness,
                             *(uint32_t *)&eigen.stress_resilience,
                             *(uint32_t *)&eigen.differentiation_axis,
                             *(uint32_t *)&eigen.mechanical_state);
  if (payload_len < 0) return -1;
  uint32_t checksum = fnv1a_checksum(payload);
  int total = snprintf(buffer, buffer_size, "XDX1.%s.%08x", payload, checksum);
  return (total < 0 || (size_t)total >= buffer_size) ? -1 : total;
}
