export const VERSION = "XDX1";

export const LIMITS = Object.freeze({
  minSize: 4,
  maxSize: 20,
  maxPath: 120,
  maxWaves: 24,
  maxSpawnCount: 200,
  maxHeat: 500,
  maxEncodedLength: 1200
});

const hasNaNOrInfinity = (value) => !Number.isFinite(value) || Number.isNaN(value);

export function serialize(level) {
  return {
    s: level.size,
    p: level.path.map(([x, y]) => [x, y]),
    w: level.waves.map(({ t, c }) => [t, c]),
    h: level.heat,
    ...(level.r ? { r: level.r } : {})
  };
}

export function deserialize(compact) {
  return {
    size: compact.s,
    path: compact.p.map(([x, y]) => [x, y]),
    waves: compact.w.map(([t, c]) => ({ t, c })),
    heat: compact.h,
    ...(compact.r ? { r: compact.r } : {})
  };
}

function clampInt(value, min, max) {
  if (hasNaNOrInfinity(value)) return min;
  return Math.max(min, Math.min(max, Math.round(value)));
}

export function validate(level) {
  if (!level || typeof level !== "object") {
    return { ok: false, reason: "Level payload is missing." };
  }

  const size = clampInt(level.size, LIMITS.minSize, LIMITS.maxSize);
  if (!Array.isArray(level.path) || level.path.length < 2 || level.path.length > LIMITS.maxPath) {
    return { ok: false, reason: "Path length is invalid." };
  }

  const path = [];
  const seen = new Set();
  for (const point of level.path) {
    if (!Array.isArray(point) || point.length !== 2) {
      return { ok: false, reason: "Path contains malformed coordinates." };
    }
    const x = clampInt(point[0], 0, size - 1);
    const y = clampInt(point[1], 0, size - 1);
    if (x < 0 || y < 0) {
      return { ok: false, reason: "Path coordinates cannot be negative." };
    }
    const key = `${x},${y}`;
    if (seen.has(key)) {
      return { ok: false, reason: "Path cannot revisit the same tile." };
    }
    seen.add(key);
    path.push([x, y]);
  }

  if (!Array.isArray(level.waves) || level.waves.length < 1 || level.waves.length > LIMITS.maxWaves) {
    return { ok: false, reason: "Wave count is invalid." };
  }

  const waves = [];
  for (const wave of level.waves) {
    if (!wave || typeof wave !== "object") {
      return { ok: false, reason: "Wave entry is malformed." };
    }
    const t = clampInt(wave.t, 1, 9);
    const c = clampInt(wave.c, 1, LIMITS.maxSpawnCount);
    if (hasNaNOrInfinity(t) || hasNaNOrInfinity(c) || t < 1 || c < 1) {
      return { ok: false, reason: "Wave values must be finite positive integers." };
    }
    waves.push({ t, c });
  }

  const heat = clampInt(level.heat, 0, LIMITS.maxHeat);
  if (heat < 0 || hasNaNOrInfinity(heat)) {
    return { ok: false, reason: "Heat is invalid." };
  }

  return {
    ok: true,
    level: {
      size,
      path,
      waves,
      heat,
      ...(typeof level.r === "string" ? { r: level.r.slice(0, 2048) } : {})
    }
  };
}

function lzwCompress(input) {
  const dict = new Map();
  const data = Array.from(input);
  const out = [];
  let phrase = data[0] || "";
  let code = 256;

  for (let i = 1; i < data.length; i += 1) {
    const currentChar = data[i];
    const combo = phrase + currentChar;
    if (dict.has(combo)) {
      phrase = combo;
    } else {
      out.push(phrase.length > 1 ? dict.get(phrase) : phrase.charCodeAt(0));
      dict.set(combo, code);
      code += 1;
      phrase = currentChar;
    }
  }
  if (phrase !== "") {
    out.push(phrase.length > 1 ? dict.get(phrase) : phrase.charCodeAt(0));
  }
  return out;
}

function lzwDecompress(codes) {
  if (!codes.length) return "";
  const dict = new Map();
  let current = String.fromCharCode(codes[0]);
  let old = current;
  let out = [current];
  let code = 256;

  for (let i = 1; i < codes.length; i += 1) {
    const currCode = codes[i];
    if (currCode < 256) {
      current = String.fromCharCode(currCode);
    } else if (dict.has(currCode)) {
      current = dict.get(currCode);
    } else {
      current = old + old[0];
    }
    out.push(current);
    dict.set(code, old + current[0]);
    code += 1;
    old = current;
  }
  return out.join("");
}

function codesToBase64url(codes) {
  const bytes = new Uint8Array(codes.length * 2);
  for (let i = 0; i < codes.length; i += 1) {
    bytes[i * 2] = (codes[i] >> 8) & 255;
    bytes[i * 2 + 1] = codes[i] & 255;
  }
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64urlToCodes(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((base64url.length + 3) % 4);
  const binary = atob(base64);
  if (binary.length % 2 !== 0) throw new Error("Corrupt compressed payload.");
  const codes = [];
  for (let i = 0; i < binary.length; i += 2) {
    const hi = binary.charCodeAt(i);
    const lo = binary.charCodeAt(i + 1);
    codes.push((hi << 8) | lo);
  }
  return codes;
}

async function checksum8(text) {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  const bytes = Array.from(new Uint8Array(hash).slice(0, 4));
  return bytes.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function encodeLevel(level) {
  const valid = validate(level);
  if (!valid.ok) throw new Error(valid.reason);
  const json = JSON.stringify(serialize(valid.level));
  const payload = codesToBase64url(lzwCompress(json));
  const sum = await checksum8(payload);
  const token = `${payload}.${sum}`;
  if (token.length > LIMITS.maxEncodedLength) {
    throw new Error(`Encoded level too large (${token.length} chars).`);
  }
  return token;
}

export async function decodeToken(token) {
  const [payload, sum] = token.split(".");
  if (!payload || !sum) throw new Error("Malformed token.");
  const expected = await checksum8(payload);
  if (expected !== sum) throw new Error("Checksum mismatch.");
  const json = lzwDecompress(base64urlToCodes(payload));
  const compact = JSON.parse(json);
  const level = deserialize(compact);
  const valid = validate(level);
  if (!valid.ok) throw new Error(valid.reason);
  return valid.level;
}

export function parseHash(hash) {
  const normalized = (hash || "").replace(/^#/, "");
  if (!normalized.startsWith(`${VERSION}.`)) {
    throw new Error("Unsupported or missing level version.");
  }
  return normalized.slice(VERSION.length + 1);
}


const EIGENSTATE_FIELD_COUNT = 6;

function checksum8Sync(text) {
  let h = 2166136261;
  for (let i = 0; i < text.length; i += 1) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0).toString(16).padStart(8, "0");
}

export function encodeEigenstate(eigenstate) {
  const fields = [
    eigenstate.energy_setpoint,
    eigenstate.epigenetic_profile,
    eigenstate.cascade_readiness,
    eigenstate.stress_resilience,
    eigenstate.differentiation_axis,
    eigenstate.mechanical_state
  ];
  if (fields.some((value) => !Number.isFinite(value))) {
    throw new Error("Eigenstate fields must be finite numbers.");
  }

  const bytes = new Uint8Array(EIGENSTATE_FIELD_COUNT * 4);
  const view = new DataView(bytes.buffer);
  for (let i = 0; i < fields.length; i += 1) {
    view.setFloat32(i * 4, fields[i], false);
  }
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
  const payload = btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
  return `${VERSION}.${payload}.${checksum8Sync(payload)}`;
}

export function decodeEigenstate(token) {
  const [version, payload, checksum] = token.split(".");
  if (version !== VERSION) throw new Error("Unsupported or missing level version.");
  if (checksum8Sync(payload) !== checksum) throw new Error("Checksum mismatch.");

  const base64 = payload.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((payload.length + 3) % 4);
  const binary = atob(base64);
  if (binary.length !== EIGENSTATE_FIELD_COUNT * 4) throw new Error("Malformed Eigenstate payload.");

  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  const view = new DataView(bytes.buffer);

  return {
    energy_setpoint: view.getFloat32(0, false),
    epigenetic_profile: view.getFloat32(4, false),
    cascade_readiness: view.getFloat32(8, false),
    stress_resilience: view.getFloat32(12, false),
    differentiation_axis: view.getFloat32(16, false),
    mechanical_state: view.getFloat32(20, false)
  };
}

export const codex_encode_eigenstate = encodeEigenstate;
export const codex_decode_eigenstate = decodeEigenstate;

export function deterministicSeedFromToken(token) {
  let h = 2166136261;
  for (let i = 0; i < token.length; i += 1) {
    h ^= token.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function createSeededRng(seed) {
  let t = seed >>> 0;
  return () => {
    t += 0x6d2b79f5;
    let n = Math.imul(t ^ (t >>> 15), 1 | t);
    n ^= n + Math.imul(n ^ (n >>> 7), 61 | n);
    return ((n ^ (n >>> 14)) >>> 0) / 4294967296;
  };
}
