# Version Prototyping Goals

## Version
- Document version: **CODEX v0.001**
- Scope target: **Tower-defense war-maul style prototype foundation**

## Purpose & justification
Define a short-horizon prototyping outline that focuses on high-signal mechanics first: lane pressure, tactical build decisions, and map evolution. The goal is to validate replayability with deterministic seed-driven levels before adding larger content systems.

## Core prototyping goals (outline)
1. Establish a war-maul-inspired loop where players build towers under increasing wave pressure.
2. Use simple deterministic pathing so enemy behavior is readable and debuggable.
3. Build progression depth through tower upgrades and structural specialization.
4. Introduce inter-wave terrain edits that let players reshape maze routes strategically.

## Discrete game mechanics

### 1) War-maul-style defensive pressure loop
- **Wave staging:** timed waves with short prep windows.
- **Economy:** gold/credits from kills and wave clear bonuses.
- **Fail condition:** shared life pool reduced when mobs exit the maze.
- **Victory cadence:** survive target wave count or boss wave.
- **Intent:** preserve the recognizable risk/reward rhythm of classic war-maul experiences.

### 2) Seeded prebuild maze and simple mob pathing
- **Seed-based generation:** each level seed defines a prebuilt maze skeleton (majority of tiles fixed at load).
- **Path representation:** grid graph with low-cost A* or BFS path recalculation only when geometry changes.
- **Mob behavior baseline:** mobs follow shortest valid path to exit; no advanced steering in prototype phase.
- **Debug visibility:** optional path overlay for confirming deterministic routing by seed.
- **Intent:** guarantee predictable tuning while still enabling variety across seeds.

### 3) Tower level building upgrades and structure modifications
- **Level tiers:** each tower has at least 3 upgrade levels with linear-to-branching stat growth.
- **Upgrade axes:** damage, fire rate, range, utility (slow/armor break/splash) as discrete choices.
- **Structure mods:** convert a base tower into archetypes (e.g., cannon -> siege, pulse, support).
- **Cost curve:** escalating upgrade cost to force trade-offs between breadth (new towers) and depth (upgrades).
- **Intent:** make build planning meaningful without introducing excessive UI complexity.

### 4) Terrain modifications between waves
- **Edit phase:** terrain modifications allowed only during inter-wave prep.
- **Legal edits:** open/close selected maze cells, place barricades, or reroute chokepoints within constraints.
- **Validation rules:** at least one valid spawn-to-exit path must always exist.
- **Counter-pressure:** terrain edits consume a strategic resource to prevent full path-lock exploits.
- **Intent:** create a dynamic board state where every wave can be approached differently.

## Prototype acceptance criteria
- Seed replay produces identical maze layout and baseline mob pathing for same configuration.
- At least one complete map can be beaten through tower upgrading choices alone.
- Terrain edits measurably alter route length or chokepoint density between waves.
- Core loop remains understandable without tutorial text after one play session.

## Suggested implementation order
1. Seeded maze loader + deterministic path solver.
2. Wave loop + economy + life-state resolution.
3. Tower placement, leveling, and branch upgrade mechanics.
4. Inter-wave terrain edit system with path-validity checks.
5. Balancing pass for pacing and anti-stall safeguards.

## Change log
- **v0.001:** Initial version prototyping goals with discrete mechanics for war-maul-style TD play, seeded maze pathing, tower progression, and between-wave terrain mutation.
