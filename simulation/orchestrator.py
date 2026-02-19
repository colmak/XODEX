from __future__ import annotations

from multiprocessing import Pool
from typing import Iterable

from codex_eigenstate import Eigenstate, decode_eigenstate, encode_eigenstate


class WasmutableOrchestrator:
    """Mutable orchestration shell that only moves CODEX Eigenstate payloads."""

    @staticmethod
    def _scale_payload(args: tuple[str, float, float]) -> str:
        payload, stress_factor, differentiation_shift = args
        eigen = decode_eigenstate(payload)
        next_eigen = Eigenstate(
            energy_setpoint=eigen.energy_setpoint,
            epigenetic_profile=eigen.epigenetic_profile,
            cascade_readiness=eigen.cascade_readiness,
            stress_resilience=max(0.0, eigen.stress_resilience * stress_factor),
            differentiation_axis=eigen.differentiation_axis + differentiation_shift,
            mechanical_state=eigen.mechanical_state,
        )
        return encode_eigenstate(next_eigen)

    def run_differentiation_sweep(self, codex_payloads: Iterable[str], shifts: Iterable[float]) -> list[str]:
        jobs = [(payload, 1.0, shift) for payload in codex_payloads for shift in shifts]
        with Pool() as pool:
            return pool.map(self._scale_payload, jobs)

    def run_stress_protocol(self, codex_payloads: Iterable[str], stress_factor: float) -> list[str]:
        jobs = [(payload, stress_factor, 0.0) for payload in codex_payloads]
        with Pool() as pool:
            return pool.map(self._scale_payload, jobs)

    def run_colony(self, codex_payloads: Iterable[str], stress_factor: float, shift: float) -> list[str]:
        jobs = [(payload, stress_factor, shift) for payload in codex_payloads]
        with Pool() as pool:
            return pool.map(self._scale_payload, jobs)
