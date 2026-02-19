import { createSeededRng } from "./codec.js";

export class XodexGame {
  constructor({ canvas, level, token }) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.level = level;
    this.token = token;
    this.tile = Math.floor(Math.min(canvas.width, canvas.height) / level.size);
    this.pathPoints = level.path.map(([x, y]) => ({ x: x * this.tile + this.tile / 2, y: y * this.tile + this.tile / 2 }));
    this.rng = createSeededRng((level.heat + 1) ^ token.length);

    this.maxLife = 20;
    this.life = this.maxLife;
    this.score = 0;
    this.blasts = [];
    this.enemies = [];
    this.waveIndex = 0;
    this.waveSpawned = 0;
    this.waveTimer = 0;
    this.globalTime = 0;
    this.complete = false;
    this.failed = false;

    this.loopHandle = 0;
    this.lastTs = 0;
    this.accumulator = 0;
    this.fixedDt = 1 / 60;

    this.onState = () => {};
    canvas.addEventListener("pointerdown", (event) => this.onPointer(event));
  }

  onPointer(event) {
    if (this.complete || this.failed) return;
    const rect = this.canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    if (this.blasts.length > 4) return;
    this.blasts.push({ x, y, life: 0.28 });
  }

  start() {
    this.lastTs = performance.now();
    const step = (ts) => {
      const dt = Math.min(0.1, (ts - this.lastTs) / 1000);
      this.lastTs = ts;
      this.accumulator += dt;
      while (this.accumulator >= this.fixedDt) {
        this.update(this.fixedDt);
        this.accumulator -= this.fixedDt;
      }
      this.render();
      this.loopHandle = requestAnimationFrame(step);
    };
    this.loopHandle = requestAnimationFrame(step);
  }

  stop() {
    cancelAnimationFrame(this.loopHandle);
  }

  spawnEnemy() {
    const wave = this.level.waves[this.waveIndex];
    if (!wave) return;
    const baseSpeed = 28 + wave.t * 8;
    const heatPenalty = Math.max(0, this.level.heat - 100) * 0.04;
    const jitter = (this.rng() - 0.5) * 4;
    this.enemies.push({ progress: 0, speed: Math.max(8, baseSpeed - heatPenalty + jitter), hp: 2 + wave.t, alive: true });
  }

  update(dt) {
    if (this.complete || this.failed) return;
    this.globalTime += dt;

    const wave = this.level.waves[this.waveIndex];
    if (wave) {
      this.waveTimer += dt;
      const interval = Math.max(0.12, 0.85 - wave.t * 0.06);
      while (this.waveSpawned < wave.c && this.waveTimer >= interval) {
        this.waveTimer -= interval;
        this.waveSpawned += 1;
        this.spawnEnemy();
      }
      if (this.waveSpawned >= wave.c && this.enemies.length === 0) {
        this.waveIndex += 1;
        this.waveSpawned = 0;
        this.waveTimer = 0;
      }
    }

    for (const blast of this.blasts) {
      blast.life -= dt;
    }
    this.blasts = this.blasts.filter((b) => b.life > 0);

    for (const enemy of this.enemies) {
      if (!enemy.alive) continue;
      enemy.progress += enemy.speed * dt;
      for (const blast of this.blasts) {
        const pos = this.positionAt(enemy.progress);
        const dx = pos.x - blast.x;
        const dy = pos.y - blast.y;
        if (dx * dx + dy * dy < 500) {
          enemy.hp -= 1;
        }
      }
      if (enemy.hp <= 0) {
        enemy.alive = false;
        this.score += 10;
      }
      if (enemy.progress >= this.pathLength()) {
        enemy.alive = false;
        this.life -= 1;
      }
    }
    this.enemies = this.enemies.filter((e) => e.alive);

    if (this.life <= 0) this.failed = true;
    if (!this.failed && this.waveIndex >= this.level.waves.length && this.enemies.length === 0) {
      this.complete = true;
    }

    this.onState({
      life: this.life,
      score: this.score,
      wave: Math.min(this.waveIndex + 1, this.level.waves.length),
      totalWaves: this.level.waves.length,
      complete: this.complete,
      failed: this.failed
    });
  }

  pathLength() {
    return (this.pathPoints.length - 1) * this.tile;
  }

  positionAt(distance) {
    const segment = this.tile;
    const idx = Math.min(this.pathPoints.length - 2, Math.floor(distance / segment));
    const t = (distance - idx * segment) / segment;
    const a = this.pathPoints[idx];
    const b = this.pathPoints[idx + 1];
    return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t };
  }

  render() {
    const { ctx, canvas } = this;
    ctx.fillStyle = "#0f172a";
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = "#1f2937";
    for (let i = 0; i <= this.level.size; i += 1) {
      const p = i * this.tile;
      ctx.beginPath(); ctx.moveTo(p, 0); ctx.lineTo(p, canvas.height); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(0, p); ctx.lineTo(canvas.width, p); ctx.stroke();
    }

    ctx.strokeStyle = "#22d3ee";
    ctx.lineWidth = 6;
    ctx.beginPath();
    this.pathPoints.forEach((p, i) => {
      if (i === 0) ctx.moveTo(p.x, p.y);
      else ctx.lineTo(p.x, p.y);
    });
    ctx.stroke();

    for (const enemy of this.enemies) {
      const pos = this.positionAt(enemy.progress);
      ctx.fillStyle = "#fb7185";
      ctx.beginPath();
      ctx.arc(pos.x, pos.y, 7, 0, Math.PI * 2);
      ctx.fill();
    }

    for (const blast of this.blasts) {
      ctx.strokeStyle = `rgba(250, 204, 21, ${blast.life / 0.28})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(blast.x, blast.y, 20 * (1 - blast.life / 0.28), 0, Math.PI * 2);
      ctx.stroke();
    }
  }
}
