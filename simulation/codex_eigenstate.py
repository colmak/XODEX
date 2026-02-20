from __future__ import annotations

import base64
import hashlib
import json
from dataclasses import dataclass
from enum import Enum

VERSION = "XDX1"


class RejectionType(Enum):
    CHECKSUM_MISMATCH = "CHECKSUM"
    ORDER_VIOLATION = "ORDER"
    SCHEMA = "SCHEMA"
    VERSION = "VERSION"


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

    def to_payload_dict(self) -> dict[str, object]:
        return {
            "schema": "eigenstate_v1",
            "energy_setpoint": self.energy_setpoint,
            "epigenetic_profile": self.epigenetic_profile,
            "cascade_readiness": self.cascade_readiness,
            "stress_resilience": self.stress_resilience,
            "differentiation_axis": self.differentiation_axis,
            "mechanical_state": self.mechanical_state,
        }


def _canonical_json_bytes(payload: dict[str, object]) -> bytes:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _checksum8(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()[:8]


def _to_b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _from_b64url(payload: str) -> bytes:
    padded = payload + "=" * ((4 - len(payload) % 4) % 4)
    return base64.urlsafe_b64decode(padded)


def encode_eigenstate(eigenstate: Eigenstate) -> str:
    raw = _canonical_json_bytes(eigenstate.to_payload_dict())
    return f"{VERSION}.{_to_b64url(raw)}.{_checksum8(raw)}"


def encode_payload(payload: dict[str, object]) -> str:
    raw = _canonical_json_bytes(payload)
    return f"{VERSION}.{_to_b64url(raw)}.{_checksum8(raw)}"


def decode_payload(token: str) -> dict[str, object]:
    version, payload, checksum = token.split(".")
    if version != VERSION:
        raise ValueError(f"Unsupported token version: {version}")
    raw = _from_b64url(payload)
    if _checksum8(raw) != checksum:
        raise ValueError("Checksum mismatch")
    return json.loads(raw.decode("utf-8"))


def decode_eigenstate(token: str) -> Eigenstate:
    payload = decode_payload(token)
    if payload.get("schema") not in {"eigenstate_v1", "eigenstate_delta_v1"}:
        raise ValueError("Unsupported eigenstate schema")
    return Eigenstate(
        float(payload["energy_setpoint"]),
        float(payload["epigenetic_profile"]),
        float(payload["cascade_readiness"]),
        float(payload["stress_resilience"]),
        float(payload["differentiation_axis"]),
        float(payload["mechanical_state"]),
    )


def decode_payload_with_rejection(token: str, *, last_version_id: int = -1) -> dict[str, object]:
    try:
        version, payload, checksum = token.split(".")
    except ValueError:
        return {"valid": False, "rejection": RejectionType.SCHEMA.value, "reason": "malformed"}
    if version != VERSION:
        return {"valid": False, "rejection": RejectionType.VERSION.value, "reason": "unsupported_version"}
    raw = _from_b64url(payload)
    if _checksum8(raw) != checksum:
        return {"valid": False, "rejection": RejectionType.CHECKSUM_MISMATCH.value, "reason": "checksum_mismatch"}
    parsed = json.loads(raw.decode("utf-8"))
    version_id = int(parsed.get("version_id", -1)) if isinstance(parsed, dict) else -1
    if version_id <= last_version_id:
        return {"valid": False, "rejection": RejectionType.ORDER_VIOLATION.value, "reason": "order_violation", "version_id": version_id}
    return {"valid": True, "payload": parsed, "version_id": version_id}
