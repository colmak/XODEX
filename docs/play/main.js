import { decodeToken, deterministicSeedFromToken, parseHash, VERSION } from "../core/codec.js";
import { XodexGame } from "../core/game.js";

const stats = document.getElementById("stats");
const status = document.getElementById("status");
const editLink = document.getElementById("editLink");

async function boot() {
  try {
    const token = parseHash(location.hash);
    const level = await decodeToken(token);
    const seed = deterministicSeedFromToken(token);
    status.textContent = `Loaded ${VERSION} token. Deterministic seed ${seed}.`;

    editLink.href = `../editor/#${VERSION}.${token}`;

    const game = new XodexGame({ canvas: document.getElementById("game"), level, token });
    game.onState = (state) => {
      stats.textContent = `Life ${state.life}/20 · Score ${state.score} · Wave ${state.wave}/${state.totalWaves}`;
      if (state.complete) status.textContent = "Victory! Share or fork by opening this link in editor.";
      if (state.failed) status.textContent = "Defeat. Open in editor to rebalance and fork.";
    };
    game.start();
  } catch (error) {
    stats.textContent = "";
    status.textContent = "Invalid or corrupted level.";
    document.getElementById("game").style.display = "none";
    console.error(error);
  }
}

boot();
