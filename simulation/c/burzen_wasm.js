export class BurzenWasmBridge {
  constructor(instance) {
    this.instance = instance;
  }

  step(dt) {
    const delta = this.instance.exports.burzen_step(dt);
    return {
      atp_eigenstate: delta.atp_eigenstate,
      fold_eigen_delta: delta.fold_eigen_delta,
      metabolic_eigen_delta: delta.metabolic_eigen_delta,
      stress_eigen_delta: delta.stress_eigen_delta,
      lysosome_pruning_delta: delta.lysosome_pruning_delta
    };
  }

  exportEigenstateCodex() {
    return this.instance.exports.export_eigenstate_codex();
  }
}
