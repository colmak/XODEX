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
