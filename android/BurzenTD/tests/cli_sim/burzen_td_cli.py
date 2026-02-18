import json
import math
import sys

# BURZEN TD CLI Simulator – Offline Text CLI for Testing & Agent Stimulation
# Pure Python, no deps, deterministic, pipeable, WASM-portable

TOWERS = {
    "hydrophobic_anchor": {"cost": 14, "heat_gen": 1.15, "tol": 0.75, "dmg": 5, "range": 3, "special": "High DPS"},
    "polar_hydrator": {"cost": 12, "heat_gen": 0.35, "tol": 0.95, "dmg": 3, "range": 4, "special": "Slow + cool"},
    "cationic_defender": {"cost": 15, "heat_gen": 0.75, "tol": 0.7, "dmg": 4, "range": 2, "special": "Push-back"},
    "anionic_repulsor": {"cost": 15, "heat_gen": 0.78, "tol": 0.7, "dmg": 6, "range": 1, "special": "Damage wall"},
    "proline_hinge": {"cost": 10, "heat_gen": 0.3, "tol": 1.0, "dmg": 2, "range": 3, "special": "Turns"},
    "alpha_helix_pulsar": {"cost": 18, "heat_gen": 1.2, "tol": 0.55, "dmg": 7, "range": 4, "special": "Pulse"},
    "beta_sheet_fortifier": {"cost": 17, "heat_gen": 0.25, "tol": 1.05, "dmg": 1, "range": 5, "special": "Barrier"},
    "molecular_chaperone": {"cost": 20, "heat_gen": -0.45, "tol": 1.3, "dmg": 0, "range": 6, "special": "Global cool"},
}

GRID_W, GRID_H = 30, 20
GRID = [["." for _ in range(GRID_W)] for _ in range(GRID_H)]

state = {
    "wave": 0,
    "enemies": [],
    "towers": [],
    "global_heat": 0.0,
    "player_cash": 100,
    "paths": [],
    "running": False,
}


def deterministic_perturb(pos):
    """Small deterministic chaos perturbation [0, 0.0099]."""
    x, y = pos
    seed = (x * 73856093 + y * 19349663 + 83492791) % 100
    return (seed / 1000.0) * 0.1


def compute_heat_at(pos):
    heat = 0.0
    for tower in state["towers"]:
        dist = math.dist(pos, tower["pos"])
        if 0 < dist <= TOWERS[tower["type"]]["range"]:
            heat += TOWERS[tower["type"]]["heat_gen"] / dist
    perturb = deterministic_perturb(pos)
    return max(0.0, heat * (1 + 0.12 * state["wave"]) + perturb)


def render_grid():
    out = []
    for y in range(GRID_H):
        line = []
        for x in range(GRID_W):
            tile = GRID[y][x]
            heat = compute_heat_at((x, y))
            symbol = tile
            if tile == "T":
                symbol = "T" if heat < 0.5 else "H" if heat < 1.0 else "O"
            elif tile == "E":
                symbol = "E"

            if (x + y) % 3 == 0:
                symbol = "/" + symbol[0] if symbol else "/"
            elif (x + y) % 3 == 1:
                symbol = "\\" + symbol[0] if symbol else "\\"
            line.append(symbol.ljust(2))
        out.append("".join(line))
    return "\n".join(out)


def process_command(cmd):
    parts = cmd.strip().split()
    if not parts:
        return {"error": "empty"}
    action = parts[0]

    if action == "place_tower":
        if len(parts) < 4:
            return {"error": "usage: place_tower <type> <x> <y>"}
        ttype, x, y = parts[1], int(parts[2]), int(parts[3])
        if ttype not in TOWERS:
            return {"error": "unknown tower"}
        if not (0 <= x < GRID_W and 0 <= y < GRID_H):
            return {"error": "out of bounds"}
        if GRID[y][x] != ".":
            return {"error": "occupied"}
        cost = TOWERS[ttype]["cost"]
        if state["player_cash"] < cost:
            return {"error": "insufficient cash"}
        state["towers"].append({"type": ttype, "pos": (x, y), "heat": 0.0})
        GRID[y][x] = "T"
        state["player_cash"] -= cost
        return {"status": "placed", "tower": ttype, "pos": [x, y], "cash": state["player_cash"]}

    if action == "start_wave":
        state["wave"] += 1
        num = int(5 * (1.5 ** state["wave"]))
        for _ in range(num):
            state["enemies"].append(
                {
                    "pos": (0, GRID_H // 2),
                    "hp": 10 * (1.2 ** state["wave"]),
                    "speed": 1 + 0.1 * (state["wave"] // 5),
                    "path_id": 0,
                }
            )
        GRID[GRID_H // 2][0] = "S"
        GRID[GRID_H // 2][GRID_W - 1] = "X"
        state["running"] = True
        return {"status": "wave_started", "wave": state["wave"], "spawned": num}

    if action == "sim_step":
        if not state["running"]:
            return {"error": "no wave"}
        for enemy in state["enemies"][:]:
            GRID[enemy["pos"][1]][enemy["pos"][0]] = "."
            enemy["pos"] = (enemy["pos"][0] + int(enemy["speed"]), enemy["pos"][1])
            if enemy["pos"][0] >= GRID_W:
                state["enemies"].remove(enemy)
                continue
            GRID[enemy["pos"][1]][enemy["pos"][0]] = "E"
            for tower in state["towers"]:
                if math.dist(enemy["pos"], tower["pos"]) <= TOWERS[tower["type"]]["range"]:
                    enemy["hp"] -= TOWERS[tower["type"]]["dmg"]
                    tower["heat"] += TOWERS[tower["type"]]["heat_gen"]
                    if tower["heat"] > TOWERS[tower["type"]]["tol"]:
                        tower["heat"] = TOWERS[tower["type"]]["tol"]
            if enemy["hp"] <= 0:
                GRID[enemy["pos"][1]][enemy["pos"][0]] = "."
                state["enemies"].remove(enemy)
                state["player_cash"] += 5
        for tower in state["towers"]:
            tower["heat"] = max(0, tower["heat"] - 0.1)
        state["global_heat"] = sum(compute_heat_at(tower["pos"]) for tower in state["towers"])
        if not state["enemies"]:
            state["running"] = False
        return {
            "status": "step",
            "enemies_left": len(state["enemies"]),
            "global_heat": round(state["global_heat"], 3),
            "cash": state["player_cash"],
        }

    if action == "query_state":
        return {
            "grid_viz": render_grid(),
            "numeric_measures": {
                "wave": state["wave"],
                "cash": state["player_cash"],
                "global_heat": round(state["global_heat"], 3),
                "tower_details": [
                    {
                        "id": i,
                        "type": tower["type"],
                        "pos": tower["pos"],
                        "heat": round(tower["heat"], 3),
                        "gen_rate": TOWERS[tower["type"]]["heat_gen"],
                        "tol": TOWERS[tower["type"]]["tol"],
                        "recovery_per_step": -0.1,
                        "dmg": TOWERS[tower["type"]]["dmg"],
                        "range": TOWERS[tower["type"]]["range"],
                    }
                    for i, tower in enumerate(state["towers"])
                ],
                "enemy_details": [
                    {"pos": enemy["pos"], "hp": round(enemy["hp"], 1), "speed": enemy["speed"]}
                    for enemy in state["enemies"]
                ],
                "poly_heat_sample": {
                    f"({x},{y})": round(compute_heat_at((x, y)), 3)
                    for y in range(GRID_H)
                    for x in range(GRID_W)
                    if GRID[y][x] in "TE"
                },
                "path_metrics": {
                    "length_tiles": GRID_W,
                    "branches": int(0.3 * state["wave"] / 10),
                    "chokes": state["wave"] // 5,
                },
            },
        }

    return {"error": f"unknown: {action}"}


if __name__ == "__main__":
    for line in sys.stdin:
        result = process_command(line)
        print(json.dumps(result, indent=None))
        sys.stdout.flush()
