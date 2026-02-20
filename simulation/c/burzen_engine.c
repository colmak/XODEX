#include "burzen_engine.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static float clampf(float v, float lo, float hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

static float average(const float *values, size_t count) {
  float total = 0.0f;
  if (count == 0) return 0.0f;
  for (size_t i = 0; i < count; i++) total += values[i];
  return total / (float)count;
}

static void params_for_tower(int tower_type, float *g, float *c, float *eta, float *gamma, float *rho, float *theta) {
  static const float table[8][6] = {
      {16.0f, 8.0f, 1.00f, 0.55f, 0.18f, 46.0f}, {14.0f, 9.0f, 0.95f, 0.82f, 0.14f, 40.0f},
      {20.0f, 5.0f, 1.08f, 0.30f, 0.22f, 52.0f}, {12.0f, 11.0f, 1.06f, 0.68f, 0.16f, 44.0f},
      {13.0f, 8.5f, 1.00f, 0.58f, 0.18f, 45.0f}, {11.0f, 7.0f, 0.96f, 0.52f, 0.17f, 48.0f},
      {10.0f, 8.0f, 1.04f, 0.61f, 0.19f, 43.0f}, {9.0f, 6.0f, 0.91f, 0.47f, 0.20f, 50.0f},
  };
  int idx = tower_type;
  if (idx < 0 || idx > 7) idx = 0;
  *g = table[idx][0];
  *c = table[idx][1];
  *eta = table[idx][2];
  *gamma = table[idx][3];
  *rho = table[idx][4];
  *theta = table[idx][5];
}

void burzen_init(BurzenSoA *soa, size_t cell_count) {
  memset(soa, 0, sizeof(*soa));
  soa->cell_count = cell_count;
  soa->energy = calloc(cell_count, sizeof(float));
  soa->heat = calloc(cell_count, sizeof(float));
  soa->activity = calloc(cell_count, sizeof(float));
  soa->tower_type = calloc(cell_count, sizeof(int));
  for (size_t i = 0; i < cell_count; i++) {
    soa->energy[i] = 30.0f;
    soa->heat[i] = 8.0f;
    soa->activity[i] = 0.7f;
    soa->tower_type[i] = (int)(i % 8);
  }
}

void burzen_destroy(BurzenSoA *soa) {
  free(soa->energy);
  free(soa->heat);
  free(soa->activity);
  free(soa->tower_type);
  memset(soa, 0, sizeof(*soa));
}

EigenstateDelta burzen_step(BurzenSoA *soa, float dt) {
  EigenstateDelta delta = {0};
  if (soa->cell_count == 0) return delta;

  for (size_t i = 0; i < soa->cell_count; i++) {
    float g, c, eta, gamma, rho, theta;
    params_for_tower(soa->tower_type[i], &g, &c, &eta, &gamma, &rho, &theta);
    float overflow = fmaxf(0.0f, (soa->heat[i] - theta) / fmaxf(theta, 1e-6f));
    float eta_eff = eta * expf(-0.9f * overflow);
    float p_gen = soa->activity[i] * g * eta_eff;
    float p_use = soa->activity[i] * c;

    float e_neighbor = 0.0f;
    float h_neighbor = 0.0f;
    for (size_t j = 0; j < soa->cell_count; j++) {
      if (i == j) continue;
      e_neighbor += 0.08f * (soa->energy[j] - soa->energy[i]);
      h_neighbor += 0.05f * (soa->heat[j] - soa->heat[i]);
    }

    soa->energy[i] = clampf(soa->energy[i] + dt * (p_gen - p_use + e_neighbor), 0.0f, 100.0f);
    soa->heat[i] = clampf(soa->heat[i] + dt * (gamma * p_use + h_neighbor - rho * soa->heat[i]), 0.0f, 100.0f);
  }

  delta.atp_eigenstate = average(soa->energy, soa->cell_count);
  delta.fold_eigen_delta = average(soa->heat, soa->cell_count);
  delta.metabolic_eigen_delta = soa->cell_count > 1 ? soa->energy[1] : soa->energy[0];
  delta.stress_eigen_delta = soa->cell_count > 2 ? soa->energy[2] : delta.metabolic_eigen_delta;
  delta.lysosome_pruning_delta = 1.0f - clampf(delta.fold_eigen_delta / 100.0f, 0.0f, 1.0f);
  return delta;
}

Eigenstate burzen_export_eigenstate(const BurzenSoA *soa) {
  Eigenstate eigen = {0};
  if (soa->cell_count == 0) return eigen;
  eigen.energy_setpoint = average(soa->energy, soa->cell_count);
  eigen.epigenetic_profile = average(soa->heat, soa->cell_count) / 100.0f;
  eigen.cascade_readiness = soa->cell_count > 1 ? soa->energy[1] / 100.0f : eigen.energy_setpoint / 100.0f;
  eigen.stress_resilience = 1.0f - eigen.epigenetic_profile;
  eigen.differentiation_axis = eigen.cascade_readiness - eigen.epigenetic_profile;
  eigen.mechanical_state = 0.5f * (eigen.energy_setpoint / 100.0f + eigen.stress_resilience);
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
  char payload[320];
  int payload_len = snprintf(
      payload, sizeof(payload),
      "{\"schema\":\"eigenstate_v1\",\"energy_setpoint\":%.6f,\"epigenetic_profile\":%.6f,\"cascade_readiness\":%.6f,\"stress_resilience\":%.6f,\"differentiation_axis\":%.6f,\"mechanical_state\":%.6f}",
      eigen.energy_setpoint, eigen.epigenetic_profile, eigen.cascade_readiness, eigen.stress_resilience,
      eigen.differentiation_axis, eigen.mechanical_state);
  if (payload_len < 0) return -1;
  uint32_t checksum = fnv1a_checksum(payload);
  int total = snprintf(buffer, buffer_size, "XDX1.%s.%08x", payload, checksum);
  return (total < 0 || (size_t)total >= buffer_size) ? -1 : total;
}
