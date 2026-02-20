#ifndef BURZEN_ENGINE_H
#define BURZEN_ENGINE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  TOWER_KINETIC = 0,
  TOWER_THERMAL = 1,
  TOWER_ENERGY = 2,
  TOWER_REACTION = 3,
  TOWER_PULSE = 4,
  TOWER_FIELD = 5,
  TOWER_CONVERSION = 6,
  TOWER_CONTROL = 7
} TowerArchetype;

typedef struct {
  float energy_setpoint;
  float epigenetic_profile;
  float cascade_readiness;
  float stress_resilience;
  float differentiation_axis;
  float mechanical_state;
} Eigenstate;

typedef struct {
  float atp_eigenstate;
  float fold_eigen_delta;
  float metabolic_eigen_delta;
  float stress_eigen_delta;
  float lysosome_pruning_delta;
} EigenstateDelta;

typedef struct {
  size_t cell_count;
  float *energy;
  float *heat;
  float *activity;
  int *tower_type;
} BurzenSoA;

void burzen_init(BurzenSoA *soa, size_t cell_count);
void burzen_destroy(BurzenSoA *soa);
EigenstateDelta burzen_step(BurzenSoA *soa, float dt);
Eigenstate burzen_export_eigenstate(const BurzenSoA *soa);
int codex_encode_eigenstate(Eigenstate eigen, char *buffer, size_t buffer_size);

#ifdef __cplusplus
}
#endif

#endif
