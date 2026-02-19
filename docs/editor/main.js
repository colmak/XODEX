import { encodeLevel, validate, VERSION, parseHash, decodeToken } from "../core/codec.js";

const canvas = document.getElementById("grid");
const ctx = canvas.getContext("2d");
const sizeInput = document.getElementById("size");
const heatInput = document.getElementById("heat");
const wavesWrap = document.getElementById("waves");
const output = document.getElementById("output");
const status = document.getElementById("status");

const model = { size: 8, path: [], waves: [{ t: 1, c: 12 }], heat: 120 };

function renderWaves() {
  wavesWrap.innerHTML = "";
  model.waves.forEach((wave, index) => {
    const row = document.createElement("div");
    row.className = "row";
    row.innerHTML = `<label>Tier <input data-i="${index}" data-k="t" type="number" min="1" max="9" value="${wave.t}"/></label>
      <label>Count <input data-i="${index}" data-k="c" type="number" min="1" max="200" value="${wave.c}"/></label>
      <button data-remove="${index}" class="secondary">Remove</button>`;
    wavesWrap.appendChild(row);
  });
}

function tileAt(event) {
  const rect = canvas.getBoundingClientRect();
  const x = event.clientX - rect.left;
  const y = event.clientY - rect.top;
  const tile = canvas.width / model.size;
  return [Math.floor(x / tile), Math.floor(y / tile)];
}

function drawGrid() {
  const tile = canvas.width / model.size;
  ctx.fillStyle = "#0f172a";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.strokeStyle = "#334155";
  for (let i = 0; i <= model.size; i += 1) {
    const p = i * tile;
    ctx.beginPath(); ctx.moveTo(p, 0); ctx.lineTo(p, canvas.height); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(0, p); ctx.lineTo(canvas.width, p); ctx.stroke();
  }
  model.path.forEach(([x, y], i) => {
    ctx.fillStyle = i === 0 ? "#22c55e" : i === model.path.length - 1 ? "#f97316" : "#22d3ee";
    ctx.fillRect(x * tile + 3, y * tile + 3, tile - 6, tile - 6);
    ctx.fillStyle = "#020617";
    ctx.fillText(String(i + 1), x * tile + tile * 0.36, y * tile + tile * 0.6);
  });
}

canvas.addEventListener("pointerdown", (event) => {
  const point = tileAt(event);
  const key = point.join(",");
  if (model.path.some((p) => p.join(",") === key)) return;
  model.path.push(point);
  drawGrid();
});

sizeInput.addEventListener("change", () => {
  model.size = Number(sizeInput.value);
  model.path = [];
  drawGrid();
});
heatInput.addEventListener("change", () => { model.heat = Number(heatInput.value); });

document.getElementById("clear").addEventListener("click", () => {
  model.path = [];
  drawGrid();
});

document.getElementById("addWave").addEventListener("click", () => {
  model.waves.push({ t: 1, c: 6 });
  renderWaves();
});

wavesWrap.addEventListener("input", (event) => {
  const target = event.target;
  if (!target.dataset.k) return;
  model.waves[Number(target.dataset.i)][target.dataset.k] = Number(target.value);
});

wavesWrap.addEventListener("click", (event) => {
  const idx = event.target.dataset.remove;
  if (idx === undefined) return;
  model.waves.splice(Number(idx), 1);
  renderWaves();
});

document.getElementById("generate").addEventListener("click", async () => {
  try {
    const valid = validate(model);
    if (!valid.ok) throw new Error(valid.reason);
    const token = await encodeLevel(valid.level);
    const url = `${location.origin}${location.pathname.replace(/\/editor\/?$/, "/play/")}#${VERSION}.${token}`;
    output.value = url;
    status.textContent = `Valid level encoded (${token.length} chars).`;
    status.className = "ok";
  } catch (error) {
    output.value = "";
    status.textContent = `Invalid or corrupted level. ${error.message}`;
    status.className = "error";
  }
});

document.getElementById("copy").addEventListener("click", async () => {
  if (!output.value) return;
  await navigator.clipboard.writeText(output.value);
  status.textContent = "Link copied to clipboard.";
  status.className = "ok";
});


async function loadFromHash() {
  if (!location.hash) return;
  try {
    const token = parseHash(location.hash);
    const level = await decodeToken(token);
    model.size = level.size;
    model.path = level.path;
    model.waves = level.waves;
    model.heat = level.heat;
    sizeInput.value = String(model.size);
    heatInput.value = String(model.heat);
    renderWaves();
    drawGrid();
    status.textContent = "Loaded level from shared link.";
    status.className = "ok";
  } catch (error) {
    status.textContent = "Could not load hash payload.";
    status.className = "error";
  }
}
renderWaves();
drawGrid();
loadFromHash();
