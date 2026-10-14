# Tank Strategy Game — Design Document

**Status:** Milestones 1 and 2 complete. Milestone 3 (AI) not started.
**Last updated:** 2026-10-04

This document explains how the game is built and, more importantly, *why* it is built that way.
The frozen phase‑1 rules themselves live in `CLAUDE.md`; this document does not repeat them, it
explains how they are implemented and which decisions are load‑bearing.

---

## 1. What exists today

A playable hot‑seat iOS game: two players share one device, five tanks each, on a 12×10 grid.
Tap a tank, see where it can go, move it, pick a target, read the damage preview, attack or wait.
The match ends by annihilation or on HP at the 40‑round limit.

| Layer | Target | Lines | Imports |
|---|---|---|---|
| Rules engine | `TankGameCore` | 804 | Foundation only |
| Scene + UI | `TankGameRendering` | 1936 | SpriteKit, `TankGameCore` |
| App shell | `IOSTankBattle` | 189 | UIKit, both libraries |
| Tests | both test targets | 1616 | — |

119 tests, all green. `swift test` runs everything.

---

## 2. The one architectural rule

**Game logic never knows that rendering exists.**

`TankGameCore` must not import UIKit, AppKit or SpriteKit. `TankGameRendering` depends on the core,
never the reverse. The app depends on both and contains almost nothing.

This is not style. It buys three concrete things:

1. **The AI can simulate futures.** `GameState` is a value type all the way down, so milestone 3 can
   copy it, apply a candidate action and score the result, with no risk of mutating the live game.
2. **Rules are testable without a screen.** The 58 core tests never touch SpriteKit at all, and
   another 37 rendering tests (`BoardInteraction`, `BoardLayout`) construct no SKNode either.
3. **Art is swappable.** Nothing in the rules has an opinion about pixels.

The corollary that is easy to violate later: **never put a reference type inside `GameState`.** One
class in there and every AI simulation silently shares mutable state with the board the player is
looking at.

---

## 3. Rules engine (`TankGameCore`)

### 3.1 Model types don't check legality

`Tank`, `GameMap`, `GameState` and `TankCommand` are dumb data. They will happily hold a tank on a
water tile or a command that targets a friend. All legality lives in `Rules`.

This is deliberate and it matters for milestone 3: the AI wants to *generate candidate actions
freely and filter them*. If the model rejected bad states at construction time, candidate generation
would need a parallel "unvalidated" representation.

### 3.2 One turn is exactly one `Action`

```swift
enum Action { case pass; case command(TankCommand) }
struct TankCommand { let tankID: TankID; let destination: Position; let targetID: TankID? }
```

A command is one tank, an optional move and an optional attack. "Stay put" is `destination ==
tank.position`; "move without firing" is `targetID == nil`. Keeping the turn to a single value makes
the AI's search space enumerable and the UI's commit path trivial.

### 3.3 `Rules.apply` is the only mutation

```swift
static func apply(_ action: Action, to state: GameState) throws -> (state: GameState, events: [GameEvent])
```

It takes a state, returns a *new* state plus an ordered event list. It throws `IllegalAction` and
changes nothing if the action is rejected, so callers may offer candidates optimistically.

**Atomicity comes from working on a copy.** `apply` makes one private copy and mutates that. If
validation fails half‑way through, it throws and the caller's state was never touched. This is what
lets the attack be validated *after* the move is applied — which turned out to be necessary (§3.5).

### 3.4 Events are the animation contract

```swift
enum GameEvent {
    case passed(Side)
    case moved(TankID, path: [Position])
    case resupplied(TankID)
    case attacked(attacker:defender:damage:destroyed:)
    case counterattacked(attacker:defender:damage:destroyed:)
    case turnBegan(Side, round: Int)
    case gameEnded(GameResult)
}
```

The renderer replays these in order; the AI ignores them entirely. `moved` carries the full path so
the board can drive the tank tile by tile instead of teleporting it. `damage` is reported **capped at
the target's remaining HP**, so a 5‑damage shell on a 1‑HP tank reports `damage: 1` — the number the
UI should show.

### 3.5 Two rule subtleties that cost real debugging

**Ammo must be checked *after* the move, not before.** The spec says a tank may move then attack, and
that arriving on your own supply tile refills ammo. Together these mean a tank with zero ammo can
drive onto its supply tile and fire in the same turn. The first implementation validated ammo against
the pre‑move tank and rejected this. The fix was to reorder `perform` to move first, then validate
the shot against the post‑move tank.

`Rules.tankAfterMove(_:to:in:)` exists for exactly this reason: it returns the tank as it *will be*
after driving somewhere, refill included. The engine uses it to apply the move, and the UI uses it to
decide which targets to highlight — so the preview and the result can never disagree.

**Mutual destruction is unreachable in play.** A destroyed defender never counterattacks, so the only
way the attacker dies is a counterattack from a defender that survived — leaving that defender alive.
`GameResult.draw` by annihilation is therefore defensive code. The test asserts it directly through
`Rules.annihilationResult` rather than pretending to reach it through a match, with a comment saying
why. Worth remembering before "simplifying" that branch away.

### 3.6 Movement

Dijkstra over orthogonal neighbours, budget = the tank's move points, cost = terrain cost to *enter*.

Two distinct queries, and the difference is the whole blocking rule:

- `movementCosts` — every tile the tank can reach **or cross**. Friendly tanks appear here.
- `reachableTiles` — `movementCosts` minus tiles occupied by another living tank, plus the tank's own
  tile. These are the tiles it may *stop* on.

Enemy tanks are never in either: they block traversal, so the search does not expand through them.
`path` reconstructs a cheapest route backwards by looking for a neighbour whose cost is exactly
`cost(tile) − costToEnter(tile)`.

The map rejects the enemy's supply tile in `canEnter(_:side:)`, which is terrain‑level and so applies
to crossing as well as stopping.

---

## 4. Rendering (`TankGameRendering`)

### 4.1 Why the scene lives in the library, not the app target

Everything except `GameViewController` is in `TankGameRendering`. That is what makes the tap flow
unit‑testable — 30 of the 101 tests drive `BoardInteraction` with no SpriteKit involved. Code in the
app target can only be tested through a UI test harness, which is slow and flaky.

The app target is a host: it owns the `SKView`, builds a `BattleScene` and feeds it safe‑area insets.

### 4.2 `BoardInteraction` — the tap flow as a pure state machine

This is the heart of milestone 2 and the file to read first.

The flow is specified by the **Tap-flow** diagram below; `BoardInteraction` implements it. As states:

```
idle ──tap own tank──▶ planning (Tile1 = its own tile; X on every enemy in range of Tile1)
planning ──tap reachable tile──▶ planning (that tile is Tile1; X's recomputed, tank stays put)
planning ──tap Tile1 again──▶ committed: move there and end its go (hold, if Tile1 is its own tile)
planning ──tap enemy with X──▶ aiming (damage preview in the status line)
aiming ──tap the SAME enemy again──▶ committed: move to Tile1, then fire
aiming ──tap Tile1 / another X / another tile──▶ as from planning
any ──Cancel──▶ idle                            End Turn ──▶ the rest of the side's turn is given up
```

```plantuml Tap-flow
@startuml
start
:User selects a tank, let name it Tank1
:User taps on a tile, let name it Tile1

if (Tile1 is reachable by Tank1) then (yes)
  if (There are some enemies in attack range of Tank1 from Tile1) then (yes)
    :Let say the list of enemies in attack range of Tank1 from Tile1 is ATTACKABLE_ENEMIES
    loop for each enemy in ATTACKABLE_ENEMIES
      :Draw a yellow X right above enemy
    end
    
    if (User taps on an enemy with X) then (attack)
      // User confirm to move Tank1 to Tile1 and attack the enemy tank with X
      :Remove X from enemies
      :Move tank Tank1 to tile Tile1 and then attack the selected enemy
    elseif (User tap on Tile1) then (just move)
      // User confirm just moving the tank Tank1 to tile Tile1 and end.
      :Remove X from enemies
      :Move the tank Tank1 to Tile1
    else
      //
    endif

  else (no)
  endif
else (no)
  :Do nothing
  :The selected tank is still being selected
endif
stop
@enduml
```

How the diagram's open branches were filled in (agreed with the author):

- **Everything is a tap.** The command bar has only Cancel and End Turn. Moving, attacking and holding
  position are all second taps: Tile1 again moves (or holds), the same X'd enemy again fires.
- **X's appear on selection.** Tile1 starts as the tank's own tile, so enemies already in range are
  marked straight away; attacking without moving is "select, tap the X, tap it again".
- **The first tap on an X previews.** The status line shows damage and counterattack; the second tap on
  the same enemy commits. Tapping a different X switches the aim; tapping another tile moves Tile1 and
  drops the aim (range depends on where the tank stops).
- **With no enemy in range of Tile1**, tapping Tile1 again moves the tank, same as "just move".
- **Holding position spends the go.** Tapping the tank twice is Tile1-again with Tile1 = its own tile.
  The old guard that ignored a double tap on a tank as a slip is gone, since there is no Wait button.
- **Nothing moves until the commit.** The tank stays put while Tile1 is chosen; the committed `.moved`
  event is what drives it (see §4.5).

It owns the `GameState` and is **the only thing that calls `Rules.apply`**. The scene never reasons
about rules; it asks `BoardInteraction` what to draw and forwards taps.

Design points:

- **Planning never mutates the game.** Tile1 is a field on `MovePlan`; the real tank does not move
  until the confirming tap. Cancel is therefore free.
- **Re‑pointing the move drops the aim.** Range depends on where you stop, so a new destination
  invalidates the target. Enforced in `tapTile`, tested explicitly.
- **Targets are computed from Tile1**, via `Rules.tankAfterMove`, so the X's and the damage preview
  already account for a supply refill.
- **`tapTile` can end the turn.** A confirming tap returns the committed events, so every caller
  must animate them. `BattleScene.tapBoard` is the single entry point for that, shared by real taps
  and `simulateTap`, because an earlier version let the test hook drop the events and the board
  silently desynced from the model.
- **Illegal commits clear the selection instead of trapping.** If the UI ever offers something the
  rules reject, `commit` swallows it and resets. A dead‑end selection the player cannot escape would
  be worse than a no‑op.

Hot‑seat falls out for free: the only gate is `tank.side == state.currentSide`. Milestone 3 replaces
the second player by feeding the AI's chosen `Action` through `Rules.apply` and calling `reset(to:)`.

### 4.3 Coordinates

The model's y axis grows **downward** (row 0 is the top row). SpriteKit's grows **upward**.
`BoardLayout` is the single place that flips it:

```swift
point.y = (height - 1 - position.y + 0.5) * tileSize
```

Every grid↔point conversion goes through `BoardLayout`. It is a pure struct with no SpriteKit
dependency, which is why it can be exhaustively round‑trip tested. A tile owns its lower and left
edges; `BoardLayoutTests` pins that boundary down so a future tile‑size change cannot quietly shift
taps by one row.

### 4.4 Drawing

`BoardNode` holds four layers by z‑order: terrain (0), highlights (2), tanks (10), effects (20).

All game art goes through `SpriteCatalog`, never `SKSpriteNode(imageNamed:)`. A missing image yields
a placeholder shape, so a partial art set is always playable and never shows a red X.
`SpriteCatalog.missingRequiredAssets()` is a live to‑do list — the app prints it in debug builds, and
milestone 4 is done when it returns empty.

Overlays are drawn in code, never as images, per the art rules: HP bars, ammo pips, selection ring,
tile highlights, path hint. They live in `TankSprite` and `BoardTheme`. This keeps them correct when
the placeholder shapes are replaced by real sprites.

`BoardNode.play(events:state:completion:)` replays an event list by chaining completions, then syncs
every sprite to the authoritative state. **The animation is never the source of truth** — the sync at
the end means a dropped or interrupted animation cannot desynchronise the board from the model.

### 4.5 Tanks only move by replaying committed events

A tank never moves on screen before its action is committed: the `.moved` event from `Rules.apply` is
what drives it, through the same `BoardNode.play` path the AI's moves use. The sprites are therefore
never ahead of the rules, and the only busy states are "animating events" and "Red is thinking".

There used to be a second mechanism that drove the *sprite* ahead of the model while a move was being
planned (`previewTankID`, `PreviewRoute`, `BoardNode.drivePreview`). It was removed with the Tap-flow,
which never needs it — and it was the source of a deadlock: End Turn with a tank parked on a planned
tile drove that tank home, Red's turn was refused while it rolled, and the drive's completion never
asked for it again, so the board locked for good. `BattleSceneAITests.testRedStillPlaysAfterBluesFirstMoveAndEndTurn`
pins that scenario down.

The rule for anything that makes the scene busy in future: when it finishes, call
`advanceAIIfNeeded()`. That function refuses to schedule Red while anything is busy, so whatever was
busy is responsible for asking again.

### 4.6 Input gating

`BattleScene` ignores board taps while `isAnimating`. The HUD gets first refusal on every tap, then
the game‑over overlay, then the board. Button hit‑testing walks up from the hit node because taps
land on a button's background or label, not the button itself — one shared `ButtonNode.hitTest`
rather than three hand‑rolled ancestor walks.

### 4.7 Safe area

The HUD bars' backgrounds run to the physical screen edge (so the notch area stays dark) while their
*text* is inset. `BoardInsets` is passed from `GameViewController.viewDidLayoutSubviews`, which is
also where the scene is created — building it in `viewDidLoad` would size the board to the
storyboard's 375×667 instead of the device.

---

## 5. Testing strategy

| Suite | Tests | Covers |
|---|---|---|
| MovementTests | 9 | Dijkstra, terrain cost, friendly/enemy blocking, supply ownership, paths |
| CombatTests | 11 | Damage, ammo, counterattack conditions, overkill clamping, rejections |
| TargetingTests | 6 | Range bands, artillery dead zone, destroyed tanks, firing from a planned tile |
| SupplyTests | 5 | Refill on arrival only, leave‑and‑return, refill‑then‑fire, enemy exclusion |
| TurnFlowTests / EndConditionTests | 11 | Alternation, rounds, annihilation, HP at limit, draw |
| Model + config suites | 16 | Parsing, validation, JSON round trip |
| BoardInteraction* | 39 | The whole tap flow, hot‑seat alternation, end‑of‑match lockout |
| BoardLayoutTests | 7 | Grid↔point round trip, edge ownership, fit scaling |
| PreviewRouteTests | 9 | Route stitching: extend, shorten, diverge, cancel, single steps |
| SpriteCatalog / AssetName | 6 | Placeholder fallback, asset naming |

Conventions worth keeping:

- **Tests build their own small ASCII maps** rather than using `Maps.crossing`, so each test shows the
  exact board it depends on. A 5×5 map in the test file is readable; a 12×10 one is not.
- **Assertion messages state the rule**, not the mechanic: `"Enemy tanks cannot be crossed to reach
  what is behind them"` survives a refactor that renames the function.
- Edge cases are the point. Overkill clamping, zero‑ammo defenders, destroyed tanks as shooters and
  as targets, the round‑limit boundary, and the refill‑then‑fire interaction all have dedicated tests
  because all of them were wrong at some point.

Visual behaviour was verified by running on the simulator and screenshotting each state (board,
selection + highlights + path, damage preview, game over). That is not automated; it is a manual step
before calling a rendering change done.

---

## 6. Known gaps and deliberate omissions

- **No AI.** `currentSide == .ai` is driven by the second human. Milestone 3.
- **One map.** `Maps.crossing` is hard‑coded in `GameViewController`. Map selection is milestone 4.
- **No floating damage numbers.** Listed under milestone 4 polish; the HUD preview covers the
  decision‑making need for now.
- **No persistence.** Quitting loses the match. Not in phase 1 scope.
- **`GameConfig` is JSON‑loadable but never loaded from JSON.** `GameConfig.phase1Default` is used
  throughout. The loading path exists and is tested; nothing ships a config file yet.
- **Placeholder art only.** Every `AssetName.required` entry is currently missing, so the whole board
  renders as shapes. This is stage 1 by design.

---

## 7. What milestone 3 should touch

The AI needs no new rules. The pieces are already public:

- `Rules.reachableTiles(for:in:)` → candidate destinations
- `Rules.attackableTargets(for:from:in:)` → candidate targets from each destination
- `Rules.preview(attacker:target:from:in:)` → damage dealt and counter damage taken, without applying
- `Rules.apply` → commit the chosen action

A greedy AI is: enumerate `(tank, destination, target?)` plus `.pass`, score each with `preview` and a
threat map, take the best. The scoring terms are listed in `CLAUDE.md`.

**Where it plugs in:** `BattleScene` currently lets the human act for both sides. Add an AI driver
that, when `interaction.currentSide == .ai`, picks an `Action`, applies it and animates the resulting
events through the same `BoardNode.play` path the human turn already uses. `BoardInteraction` gains
nothing new; it already has `reset(to:)` for an externally advanced state.

The one thing to watch: the AI will call `Rules.apply` thousands of times per turn on copied states.
That is fine today (12×10, 5 tanks), and it stays fine only as long as `GameState` holds no reference
types — see §2.
