# Tank Strategy Game — Project Context

Solo-developed iOS turn-based strategy game: player vs AI, 5 tanks per side, on a 2D grid.
This package (`TankGameCore`) is the pure-Swift rules engine. It must NOT import UIKit or SpriteKit.

## Architecture principles
- Game logic is fully separate from rendering. SpriteKit (milestone 2) only reads `GameState` and animates.
- `GameState` is a value type (struct). The AI copies it to simulate futures; never introduce reference types into it.
- All balance numbers live in `GameConfig` (JSON-loadable). Never hard-code stats in rules.
- One turn = exactly one `Action`: `.pass` or `.command(TankCommand)` (one tank, optional move, optional attack).
- Model types don't check legality; rules functions do (so the AI can generate candidates and filter them).
- Every rule gets unit tests, especially edge cases.

## Phase 1 rules (frozen spec)
**Map**
- n × m square grid. Movement is orthogonal only (no diagonals).
- Terrain: open (cost 1), trees (cost 2), rocks (impassable), water/river/lake (impassable).
- No terrain blocks shots (no line of sight).
- Maps are handmade, ~12×10, 180°-rotationally symmetric. ASCII format: `.` open, `T` trees, `R` rocks,
  `W` water, `S`/`s` player/AI supply tile, `P`/`a` player/AI spawn.

**Movement**
- Reachable tiles = Dijkstra over orthogonal neighbours, budget = tank's move points, terrain costs above.
- Tanks may pass THROUGH friendly tanks, NOT through enemy tanks.
- A tank may not END its move on an occupied tile.
- Only the owning side may enter its supply tile.

**Combat**
- Range uses Manhattan distance, inclusive band [minRange, maxRange]. Artillery cannot hit adjacent (min range 2).
- A tank may attack without moving, and may move then attack in the same turn (artillery included).
- Fixed damage per tank type, no randomness. Each shot costs 1 ammo; no ammo = cannot fire.
- Defender counterattacks once if it survives, has ammo, AND the attacker is within the DEFENDER's range.
  Counterattack uses the defender's damage and consumes the defender's ammo.
- A counterattack never triggers another counterattack. A counterattack can destroy the attacker.
- A tank at 0 HP is destroyed and ignored by all rules (it stays in `tanks` for stable IDs).

**Supply tile**
- One per side. On ARRIVAL (a move ending there from a different tile), the tank refills ammo AND HP to full.
- Staying on the tile does not refill again; the tank must leave and come back.

**Turns and end of game**
- Player always moves first. Either side may pass.
- One round = one player action + one AI action. Limit: 40 rounds.
- Win: all enemy tanks destroyed.
- At the round limit: the side with more total remaining HP wins (destroyed = 0 HP); equal HP = draw.

**Tank stats (starting values for playtesting)**

| Type | Count | Move | Range | HP | Damage | Ammo |
|---|---|---|---|---|---|---|
| Light | 2 | 5 | 1 | 6 | 3 | 6 |
| Medium | 2 | 3 | 1–2 | 10 | 4 | 5 |
| Artillery | 1 | 2 | 2–4 | 7 | 5 | 3 |

**Out of scope for phase 1:** diagonal movement, line of sight, random damage, terrain defense bonuses,
enemy access to supply tiles, multiplayer, procedural maps, look-ahead AI, campaign/progression.

## Task list
Milestone 1 — logic core (this package)
- [x] 1. Data models: Position, Terrain, TankKind/TankStats, GameConfig, Tank, GameMap (+ ASCII parser), GameState, Action
- [ ] 2. Reachable tiles (Dijkstra, blocking rules) — planned API: `Rules.reachableTiles(for:in:)`
- [ ] 3. Attackable targets (Manhattan, min/max range, ammo)
- [ ] 4. Combat: damage, ammo, destruction, single counterattack
- [ ] 5. Supply tile refill on arrival, owner-only
- [ ] 6. Turn flow: alternate sides, pass, round counter
- [ ] 7. Win/end conditions (annihilation, round limit, draw)
- [ ] 8. Unit tests for all rules and edge cases

Milestone 2 — SpriteKit board, hot-seat 2 players: render grid/tanks; tap-select → reachable tiles → move → targets →
Attack/Wait; HUD (HP, ammo, round, turn, Pass); damage preview incl. counterattack; game-over screen.

Milestone 3 — greedy AI: enumerate all legal actions incl. pass; score = damage dealt + kill bonus − counter damage
taken − exposure (threat map) + approach-enemy term + bonus for damaged tank heading to supply; readable delay/animation.

Milestone 4 — polish: animations, damage numbers, sound, 2–3 maps + map select, playtesting/balance.

Later: 2-ply minimax with alpha-beta; difficulty levels; possibly self-play RL experiments.

## Commands
- `swift test` — run all tests. Keep them green before marking a task done, and update the checklist above.
