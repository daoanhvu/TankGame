# Tank Strategy Game — Project Context

Solo-developed iOS turn-based strategy game: player vs AI, 5 tanks per side, on a 2D grid.
This Swift package has three library targets:
- `TankGameCore`: the pure-Swift rules engine. It must NOT import UIKit, AppKit or SpriteKit.
- `TankGameRendering`: SpriteKit-facing helpers (`AssetName`, `SpriteCatalog`). Depends on the core, never the reverse.
- `TankGameAI`: the opponent's brain. Depends on the core only — never on the renderer, and the core never
  depends on it — so a smarter brain can replace it without touching the rules or the board.

The iOS app (milestone 2) will be an Xcode project that depends on both libraries.

## Architecture principles
- Game logic is fully separate from rendering. SpriteKit (milestone 2) only reads `GameState` and animates.
- `GameState` is a value type (struct). The AI copies it to simulate futures; never introduce reference types into it.
- All balance numbers live in `GameConfig` (JSON-loadable). Never hard-code stats in rules.
- One `Action` = one tank's orders: `.pass` or `.command(TankCommand)` (one tank, optional move, optional
  attack). A TURN is one action per tank: the side keeps the board until every living tank has acted, or
  until it passes. `GameState.actedThisTurn` is what remembers who has had their go.
- Model types don't check legality; rules functions do (so the AI can generate candidates and filter them).
- Every rule gets unit tests, especially edge cases.

## Phase 1 rules (frozen spec)
**Map**
- n × m square grid. Movement is orthogonal only (no diagonals).
- Terrain: open (cost 1), trees (cost 2), rocks (impassable), water/river/lake (impassable).
- No terrain blocks shots (no line of sight).
- Maps are handmade, ~12×10, 180°-rotationally symmetric. ASCII format: `.` open, `T` trees, `R` rocks,
  `W` water, `S`/`s` player/AI supply tile, `P`/`a` player/AI spawn.
- Maps can also come from the Tiled editor: `TiledMap` (core, Foundation only) parses a `.tmj` plus its
  `.tsj` tilesets — tile layers (gids with flip flags) and tilesets. `GameMap(tiled:supplyTiles:spawnTiles:)`
  reads the gameplay from each layer's per-cell `types` array: `OPEN` passable, `NO_PASS` blocked (read as
  rocks), `WATER` blocked, `""` no opinion; stacked layers, most restrictive wins. The per-cell types are
  what counts, not the tileset's own tile types (the editor overrides them per cell). The format has no
  supply/spawn markers, so those are passed in code. `Maps.twinLakes()` returns `(map, tiled)`: 12×18 of
  92×92 tiles (`tank921218.tmj`), Red top-right (supply 9,0), Blue bottom-left (supply 2,17). Depots and
  spawns are exact 180° turns of each other; the terrain only roughly (22 of 52 blocked cells have no
  blocked twin). The art's tile size is independent of the board's 64-point layout tile: `TiledArt`
  composes at the tileset's own resolution and the sprite is scaled to the board. Its files live in
  `Sources/TankGameCore/Resources`; to update the map, re-export from the editor and copy the `.tmj`/`.tsj`
  over them. `BoardNode(art:)` composes the tile layers into ONE image (`TiledArt`, no seams between tiles)
  under a faint grid; tileset images are app assets named `AssetName.tileset(<tileset name>)`, e.g.
  `tileset_green_grass_bg_92`. Any missing tileset image = the board falls back to terrain tiles.

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
- A TURN of a side ends when every one of its living tanks has moved/attacked, or when that side passes.
  Each tank acts exactly once per turn (`IllegalAction.tankAlreadyActed` otherwise); the player picks the
  order by tapping. Passing gives up the rest of the turn, leaving unused tanks where they stand.
- Player always moves first. Either side may pass.
- One round = one player turn + one AI turn. Limit: 40 rounds — generous now that a round holds up to ten
  tank actions: greedy-vs-greedy ends by annihilation around round 14, and against a passive player by
  round 9, so the HP tie-break is rarely what decides a match.
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

Two things about that list, both consequences of a turn being several actions:
- `.turnBegan` fires only when the side actually changes, never between two tanks of the same side.
- An action can produce NO events at all — a tank told to hold its position has nothing to animate. That is
  not the same as the rules declining the action, and `BattleScene` tells them apart by whether the state
  moved. Read an empty list as "nothing happened" and the board deadlocks mid-turn with input locked.

Milestone 2 — SpriteKit board, hot-seat 2 players — DONE
- [x] Render grid/tanks, all visuals via `SpriteCatalog` placeholders
- [x] Tap-select → reachable tiles → move → targets → Attack/Wait
- [x] HUD (HP, ammo, round, turn, Pass) and per-tank HP bars + ammo pips
- [x] Damage preview including the counterattack
- [x] Game-over screen with a rematch button

The scene code is in `TankGameRendering` (not the app target) so it is unit-testable:
- `BoardInteraction` — the whole tap flow as a pure state machine; the only thing that calls `Rules.apply`.
  It implements the Tap-flow diagram in `docs/design.md` §4.2: everything is a tap (Tile1, the yellow X,
  tap again to commit); the command bar has only Cancel and End Turn. Tanks move on screen only by
  replaying committed events — anything that makes the scene busy must call `advanceAIIfNeeded()` when
  it finishes, or Red's turn is never scheduled (that was the "Red got stuck" bug).
- `BoardNode` / `TankSprite` — drawing and event animations. `BoardLayout` converts grid ↔ points
  (the model's y grows DOWN, SpriteKit's grows UP, so every conversion flips y). `BoardNode.driveSpeed`
  (`DriveSpeed`) sets seconds per tile by tank type — light 0.10, medium 0.16, artillery 0.24, so each
  type's full move takes ~0.5s. Presentation only; how far a tank may go is `movePoints` in `GameConfig`.
- `HUDNode`, `UnitCardNode`, `ButtonNode`, `CommandIcons`, `GameOverNode`, `BoardFrameNode` — the
  chrome, all drawn in code, following `docs/ScreenDesign.png`: operation/turn header, one unit card
  above the field for either side, the sector strip, the status line and the segmented command bar
  (the design's second card is gone; one shared card describes whichever tank is in focus, and the
  stripe down its edge says whose it is). `BoardTheme` holds every color
  and `TextStyle`/`BoardFonts` the type (condensed caps, with a fallback chain for devices missing the
  face).
- `TankAtlas` / `TankSkin` — tank art from `IOSTankBattle/Art/tank_atlas.{png,json}`; blue for the
  player, red for the AI, type read from the HUD rather than the hull. See `docs/sprite_design.md`.
- `BattleScene` — routes taps and blocks input while animating.
The app's `GameViewController` just presents `BattleScene` and feeds it the safe-area insets.

Milestone 3 — greedy AI
- [x] Engine in `TankGameAI`, behind the `TankAI` protocol (`chooseAction(in:) -> Action`), the one seam every
      later brain implements:
      - `ActionGenerator` — every legal action incl. pass, in a stable order (reachable tiles come out of a
        dictionary, so without sorting the AI would pick different equal-scoring moves on different runs).
      - `ThreatMap` — where each enemy could drive and shoot next turn. `strongestShot(at:)` is the real
        one-turn risk (a side gets ONE action); `damage(at:)` sums every gun that bears and is only a
        "how contested is this ground" hint.
      - `GreedyEvaluator` + `AIWeights` — score = damage + kill bonus − counter damage − exposure + approach
        + supply, all weights Codable like `GameConfig`. Exposure and approach are measured as a CHANGE from
        the tank's current tile, because one score ranks candidates across all five tanks.
      - `GreedyAI` (deterministic unless `weights.jitter` is set), `RandomAI` (the control group),
        `AIMatch` (headless self-play: `play`, `tally`, and `takeAction` as the reference for driving one
        action of an AI turn).
- [x] Wired into the board: the player commands Blue, the AI commands Red.
      - `BoardInteraction.aiSide` (nil = the milestone-2 hot seat) gates every input on `acceptsInput`, so a
        tap can never spend Red's turn, and `takeAIAction(with:)` is the AI's way in (ONE tank, called
        again and again while `isAITurn` holds) — still the only place that calls `Rules.apply`. An illegal
        action from a brain costs that tank its go instead of wedging the match.
      - `BattleScene.opponent` (default `GreedyAI()`, settable mid-match for a difficulty switch) and
        `opponentDelay` (0.3s, spent before EACH of Red's tanks) — it plays one of Red's actions after
        anything that could end Blue's, then animates it through the same path a tapped move uses and comes
        back for the next tank. `isAcceptingInput` is the "ready for a tap" signal; `isOpponentTurn` and the
        round counter both go stale while Red's last move is still animating, so tests wait on the former.
      - The HUD reads ROUND (not TURN — a round is two turns now), the status line counts the units still
        awaiting orders, and tanks that have had their go are greyed out by `TankSprite.setSpent`.
      - `GameViewController` needed no change: the app links `TankGameAI` transitively through
        `TankGameRendering`, so there is nothing to add in Xcode.

Three tuning traps, all covered by regression tests in `TankGameAITests` — mind them when rebalancing. The
sharpest single check is `testFinishesOffAPlayerThatNeverMoves`: against five stationary tanks the AI has to
win by annihilation inside the round limit, and every one of these bugs showed up there as a win on HP.
- Price exposure anywhere near `approachBonus` and two brains advance to the edge of each other's range and
  stop, because every step into contact costs more than the ground it wins: a 40-round draw at full HP.
  Exposure picks the quieter of two similar tiles; `lethalExposurePenalty` (symmetric: entering and escaping)
  is the only brake allowed to stop a tank, and it only trips for one a single shot could kill.
- Pay the supply bonus only on arrival and a wounded tank three tiles from the depot never sets off, so it
  parks for the rest of the match. `supplyApproachBonus` pays for the ground covered, scaled by how badly
  the tank needs the trip.
- Measure "closer to the enemy" as the crow flies and the whole army parks on the near bank of the river:
  every detour round the water reads as zero progress. Approach and the supply pull both follow
  `DistanceField`, a Dijkstra flood with the same terrain costs as movement.
- Price the counterattack at parity (`counterDamage` 1.0) and the AI sits on a winning position refusing to
  fire, because every opening trade a light can make against a medium is 3 out for 4 back and one ply cannot
  see the teammate who finishes the target next turn. It is 0.7: a point dealt is worth a little more than a
  point taken, with `lossPenalty` and `lethalExposurePenalty` as the brakes on actually throwing tanks away.

Known limits of one ply: it can be baited (it chases a tank parked just outside artillery range), and a
wounded tank will shuttle between the front and a full-heal depot. Both are the search depth, not the weights.
The shuttle gets worse the bigger the map: on a 16×20 test map greedy-vs-greedy ended in a round-40 draw
after its survivors ferried to and from the depots. On the 12×18 twin lakes it still ends by annihilation
(round 17), and against a passive or random side by round 10–13.

Milestone 4 — polish: import Kenney Top-down Tanks Redux into Assets.xcassets with `AssetName` names
(until `missingRequiredAssets()` is empty), app icon, animations, damage numbers, sound, 2–3 maps + map select
(the app now opens on twin lakes; `crossing` is still the map most tests are tuned on),
playtesting/balance.

Later: 2-ply minimax with alpha-beta; difficulty levels; possibly self-play RL experiments.

## Commands
- `swift test` — run all tests (on macOS; `TankGameRendering` needs SpriteKit, so it won't build on Linux). Keep them green before marking a task done, and update the checklist above.
  If it reports `no such module 'XCTest'`, the shell is on the Command Line Tools toolchain, which has no
  XCTest: run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` (or `sudo xcode-select -s`).
