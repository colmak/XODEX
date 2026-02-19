from codex_eigenstate import Eigenstate, decode_eigenstate, encode_eigenstate


def test_codex_eigenstate_round_trip():
    eigen = Eigenstate(0.8, 0.42, 0.73, 0.65, -0.1, 0.5)
    token = encode_eigenstate(eigen)
    decoded = decode_eigenstate(token)
    for left, right in zip(eigen.as_tuple(), decoded.as_tuple()):
        assert abs(left - right) < 1e-6


def test_codex_eigenstate_checksum_validation():
    eigen = Eigenstate(0.4, 0.2, 0.1, 0.9, 0.0, 0.3)
    token = encode_eigenstate(eigen)
    bad = token[:-1] + ("0" if token[-1] != "0" else "1")
    try:
        decode_eigenstate(bad)
    except ValueError as exc:
        assert "Checksum mismatch" in str(exc)
    else:
        raise AssertionError("Expected checksum mismatch")
