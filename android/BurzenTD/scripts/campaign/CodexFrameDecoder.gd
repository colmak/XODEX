extends RefCounted

class_name CodexFrameDecoder

const VERSION: String = "XDX1"
const SAFE_PAYLOAD_SIZE_BYTES: int = 65536

static func decode_frame(frame: String) -> Dictionary:
	var parts: PackedStringArray = frame.split(".")
	if parts.size() != 3:
		return {"ok": false, "error": "Malformed frame."}
	if parts[0] != VERSION:
		return {"ok": false, "error": "Unsupported version."}
	var payload: String = parts[1]
	var checksum: String = parts[2]
	if checksum != _checksum8(payload):
		return {"ok": false, "error": "Checksum mismatch."}
	var raw_bytes: PackedByteArray = Marshalls.base64_to_raw(_from_base64url(payload))
	if raw_bytes.is_empty() or raw_bytes.size() > SAFE_PAYLOAD_SIZE_BYTES:
		return {"ok": false, "error": "Payload is empty or exceeds safe size."}
	var json_text: String = raw_bytes.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not (parsed is Dictionary):
		return {"ok": false, "error": "Decoded payload is not a dictionary."}
	return {
		"ok": true,
		"payload": parsed,
		"payload_size": raw_bytes.size(),
		"checksum": checksum,
	}



static func parse_campaign_url(fragment: String) -> Dictionary:
	var cleaned: String = fragment.strip_edges()
	if cleaned.begins_with("#"):
		cleaned = cleaned.substr(1)
	var decoded: Dictionary = decode_frame(cleaned)
	if not bool(decoded.get("ok", false)):
		return {"valid": false, "reason": decoded.get("error", "decode_failed")}
	var payload: Dictionary = decoded.get("payload", {})
	if str(payload.get("schema", "")) != "campaign_sequence_v0_8":
		return {"valid": false, "reason": "schema"}
	var levels: Array = payload.get("levels", [])
	var sequence: Array[String] = []
	for level: Variant in levels:
		if level is Dictionary:
			var frame: String = str((level as Dictionary).get("eigenstate_frame", ""))
			if frame.is_empty():
				return {"valid": false, "reason": "frame_missing"}
			sequence.append(frame)
	return {
		"valid": true,
		"seed": int(payload.get("deterministic_seed", 0)),
		"sequence": sequence,
	}

static func _from_base64url(input: String) -> String:
	var padded: String = input.replace("-", "+").replace("_", "/")
	while padded.length() % 4 != 0:
		padded += "="
	return padded

static func _checksum8(text: String) -> String:
	var h: int = 2166136261
	for i: int in range(text.length()):
		h = h ^ text.unicode_at(i)
		h = int((h * 16777619) & 0xffffffff)
	return "%08x" % (h & 0xffffffff)
