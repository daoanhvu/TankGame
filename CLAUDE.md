# Tank Strategy Game — Project Context

Solo-developed iOS turn-based strategy game: player vs AI, 5 tanks per side, on a 2D grid.
This Swift package has two library targets:
- `TankGameCore`: the pure-Swift rules engine. It must NOT import UIKit, AppKit or SpriteKit.
- `TankGameRendering`: SpriteKit-facing helpers (`AssetName`, `SpriteCatalog`). Depends on the core, never the reverse.

The iOS app (milestone 2) will be an Xcode project that depends on both libraries.

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

## Art (phase 1: move fast, stay swappable)
**Stages**
1. Shapes only (milestone 2): `SpriteCatalog` placeholders. Blue = player, red = AI, letter = tank type
   (L/M/A), flat colors per terrain, outlined "+" square for supply tiles. Goal: readability before beauty.
2. One free asset pack (milestone 4): Kenney "Top-down Tanks Redux" (CC0, commercial use OK, credit optional).
   Use ONE art style only. If something is missing (e.g. water/rocks), prefer another Kenney pack or a flat tile
   in the same palette. Never mix unrelated packs.
3. Designer (later): hand over `AssetName.required` as the brief and replace images with the same names.

**Rules for code**
- Always create visuals through `SpriteCatalog` (`tankNode`, `terrainNode`, `supplyNode`, `effectTexture`).
  Never call `SKSpriteNode(imageNamed:)` directly.
- All asset names come from `AssetName`. Convention: `<category>_<variant>[_<side>]`, e.g. `tank_light_player`,
  `terrain_trees`, `supply_ai`, `fx_explosion`. Optional rotating barrel: `tank_<kind>_<side>_barrel`.
- Images live in the app's `Assets.xcassets` (bundle `.main`).
- Missing image = automatic placeholder shape, never a crash or red "X".
  `SpriteCatalog.missingRequiredAssets()` lists what is still missing.
- All tank sprites are drawn FACING UP; the catalog rotates AI hulls 180° at start.
- Tile size: 64×64 points. Tanks are drawn at 85% of a tile.
- Show tank TYPE by silhouette (hull/barrel shape), and SIDE by color.
- UI overlays are drawn in code, not as images: HP bars, ammo pips, move/attack tile highlights, selection ring.
- App icon (required by the App Store): for phase 1, one tank sprite on a flat colored background.

**Out of scope for phase 1:** diagonal movement, line of sight, random damage, terrain defense bonuses,
enemy access to supply tiles, multiplayer, procedural maps, look-ahead AI, campaign/progression.

## Task list
Milestone 1 — logic core (this package)
- [x] 1. Data models: Position, Terrain, TankKind/TankStats, GameConfig, Tank, GameMap (+ ASCII parser), GameState, Action
- [x] 2. Reachable tiles (Dijkstra, blocking rules) — `Rules.reachableTiles(for:in:)`
- [x] 3. Attackable targets (Manhattan, min/max range, ammo) — `Rules.attackableTargets(for:from:in:)`
- [x] 4. Combat: damage, ammo, destruction, single counterattack — `Rules.preview`, `Rules.apply`
- [x] 5. Supply tile refill on arrival, owner-only — `Rules.tankAfterMove(_:to:in:)`
- [x] 6. Turn flow: alternate sides, pass, round counter
- [x] 7. Win/end conditions (annihilation, round limit, draw)
- [x] 8. Unit tests for all rules and edge cases

All of the above live in `Sources/TankGameCore/Rules.swift`. `Rules.apply` returns the next state plus
a `[GameEvent]` list (moved / resupplied / attacked / counterattacked / turnBegan / gameEnded) that the
renderer replays as animations and the AI ignores.

Milestone 2 — SpriteKit board, hot-seat 2 players — DONE
- [x] Render grid/tanks, all visuals via `SpriteCatalog` placeholders
- [x] Tap-select → reachable tiles → move → targets → Attack/Wait
- [x] HUD (HP, ammo, round, turn, Pass) and per-tank HP bars + ammo pips
- [x] Damage preview including the counterattack
- [x] Game-over screen with a rematch button

The scene code is in `TankGameRendering` (not the app target) so it is unit-testable:
- `BoardInteraction` — the whole tap flow as a pure state machine; the only thing that calls `Rules.apply`.
- `BoardNode` / `TankSprite` — drawing and event animations. `BoardLayout` converts grid ↔ points
  (the model's y grows DOWN, SpriteKit's grows UP, so every conversion flips y).
- `HUDNode`, `ButtonNode`, `GameOverNode`, `BoardFrameNode` — overlays and the border around the
  field, all drawn in code. `BoardTheme` holds every color and `TextStyle`/`BoardFonts` the type
  (condensed caps, with a fallback chain for devices missing the face).
- `BattleScene` — routes taps and blocks input while animating.
The app's `GameViewController` just presents `BattleScene` and feeds it the safe-area insets.

Milestone 3 — greedy AI: enumerate all legal actions incl. pass; score = damage dealt + kill bonus − counter damage
taken − exposure (threat map) + approach-enemy term + bonus for damaged tank heading to supply; readable delay/animation.

Milestone 4 — polish: import Kenney Top-down Tanks Redux into Assets.xcassets with `AssetName` names
(until `missingRequiredAssets()` is empty), app icon, animations, damage numbers, sound, 2–3 maps + map select,
playtesting/balance.

Later: 2-ply minimax with alpha-beta; difficulty levels; possibly self-play RL experiments.

## Commands
- `swift test` — run all tests (on macOS; `TankGameRendering` needs SpriteKit, so it won't build on Linux). Keep them green before marking a task done, and update the checklist above.
