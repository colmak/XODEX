from __future__ import annotations

import base64
import hashlib
import struct
from dataclasses import dataclass

VERSION = "XDX1"
EIGENSTATE_STRUCT = struct.Struct("!6f")


@dataclass(frozen=True)
class Eigenstate:
    energy_setpoint: float
    epigenetic_profile: float
    cascade_readiness: float
    stress_resilience: float
    differentiation_axis: float
    mechanical_state: float

    def as_tuple(self) -> tuple[float, float, float, float, float, float]:
        return (
            self.energy_setpoint,
            self.epigenetic_profile,
            self.cascade_readiness,
            self.stress_resilience,
            self.differentiation_axis,
            self.mechanical_state,
        )


def _checksum8(payload: str) -> str:
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:8]


def encode_eigenstate(eigenstate: Eigenstate) -> str:
    raw = EIGENSTATE_STRUCT.pack(*eigenstate.as_tuple())
    payload = base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")
    return f"{VERSION}.{payload}.{_checksum8(payload)}"


def decode_eigenstate(token: str) -> Eigenstate:
    version, payload, checksum = token.split(".")
    if version != VERSION:
        raise ValueError(f"Unsupported token version: {version}")
    if _checksum8(payload) != checksum:
        raise ValueError("Checksum mismatch")

    padded = payload + "=" * ((4 - len(payload) % 4) % 4)
    raw = base64.urlsafe_b64decode(padded)
    values = EIGENSTATE_STRUCT.unpack(raw)
    return Eigenstate(*values)
