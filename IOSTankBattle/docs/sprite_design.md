# Sprite design — `docs/tank_atlas`

How the tank atlas becomes the game's art, what the art can and cannot do, and the order to build it in.
Nothing here is implemented yet; this is the plan to agree on first.

Everything marked *measured* was read out of `tank_atlas.png` directly, not taken from the JSON's word.

**Decisions taken (2026-10-07):** phase 1 uses blue and red tanks only; tank type is read from the HUD,
not from the hull; iPhone only, iPad deferred; `laser` parked; the `player` and `sniper` sets parked.
§3 records what follows from that.

---

## 1. What is in the atlas

`tank_atlas.png` is 1232×991, RGBA with real transparency. `tank_atlas.json` (v2.0) describes it in pixels,
`x,y` = **top-left** of each frame, plus an `anchor` per frame in SpriteKit `anchorPoint` units
(0…1, origin **bottom-left**).

**Tanks** — 6 sets × 4 "directions" × 6 frames = 144 frames.

| set | colour | silhouette | phase 1 |
|---|---|---|---|
| `ally` | blue | standard hull, thick barrel | **player, all three kinds** |
| `enemy` | red | standard hull, short thick barrel | **AI, all three kinds** |
| `player` | olive green | standard hull, medium barrel | parked |
| `sniper` | silver | slim, very long thin barrel | parked |
| `heavy` | gold | bulky, side armour, long barrel | parked |
| `artillery` | dark brass | boxy, thin barrel, side detail | parked |

Frames per set: `idle`, `move1`, `move2`, `move3`, `fire`, `destroyed`.
`move1-3` are a subtle hull/barrel jiggle, not a track cycle. `fire` adds a muzzle flash and recoil.
`destroyed` is a burning wreck with smoke that extends past the hull.

Phase 1 therefore uses **12 of the 144 tank frames** (2 sets × the `up` row). That is expected — see F1 and
§3 — and the rest stays in the atlas at no cost, since it ships as one image either way.

**Effects** — `bullet` (2 frames), `mediumShell` (4), `rocket` (2), `laser` (2, parked), `explosion` (6),
`smoke` (6), `crater` (4). Projectiles are drawn pointing **right**.

**UI icons** — `flagGreen`, `flagRed`, `starBadge`, `shield`, `medkit`, `crate`, `steelCrate`, `radar`,
`rankChevron`.

*Measured* geometry, `up` row: frames are 48–62 px wide and 69–74 px tall; the hull (widest solid row)
is **43–48 px** across — `ally` 45, `enemy` 47. Frame size changes from frame to frame within one
animation: `destroyed` is up to 11 px wider than `idle` because of the smoke plume.

---

## 2. Three findings that drive every decision below

### F1. The "directions" are not rotations — only the `up` row is trustworthy

In all four direction rows the **hull and tracks are drawn facing up**. Only the barrel changes. Worse, the
other three rows are inconsistent:

- `down` draws the barrel as one rod passing straight **through** the hull and sticking out both ends, and
  puts the `fire` muzzle flash at the **top** — i.e. behind the tank it is supposedly shooting.
- `left` / `right` draw a stubby horizontal barrel, often with a stub on *both* sides, and the `fire` flash
  lands on the wrong side (player `left/fire` flashes on the right).
- `heavy` and `artillery` `left`/`right` are barely rotated at all — their barrels still point up.

So: **use the `up` row only, and express facing with `zRotation`.** I rendered the `up` frames rotated 90°,
−90° and 180° on a mock board — they read perfectly, because the art is top-down and its shading is
near-symmetric. This also matches the rule already in `CLAUDE.md`: *"All tank sprites are drawn FACING UP;
the catalog rotates AI hulls 180°."*

If the atlas is ever regenerated with consistent 4-direction art, the loader can switch to it behind one
flag (§6, `TankAtlas.useDirectionRows`).

### F2. Frame size and anchor change within an animation

Because each frame has its own `w`, `h` and `anchor`, `SKAction.animate(with:timePerFrame:)` is **not
usable** — it swaps textures and can resize, but cannot move `anchorPoint`. Playing a frame means setting
texture, size and anchor together. That is one small custom step (§8) and the reason the atlas ships
per-frame anchors at all.

*Measured check:* the JSON anchors agree with the hull centre I measured from the pixels (`ally` `up/idle`:
JSON `[0.509, 0.522]`, measured `[0.500, 0.514]`). The anchors are trustworthy — use them directly as
`anchorPoint` and the hull lands on the tile centre with the barrel overhanging.

### F3. Resolution is fine on iPhone; iPad is deferred

The board is width-constrained and scales down to fit. On an iPhone 17 Pro (402×874 pt), `BattleScene`
computes a board scale of **≈0.47**, so a 64 pt tile draws at ~30 pt = 91 px at @3x, and a hull at 70 % of a
tile is ~64 px — from a 45 px source, a **1.4× upscale**. Fine with linear filtering.

On a 13" iPad the board scale would cap at 1.0 and the same hull becomes ~90 px from 45 px — a **2×
upscale** that will look soft. **Deferred:** when iPad comes into scope, ask the art source for a 2× atlas.
The JSON would not change, only the pixel numbers scale, so nothing in §6 is wasted work.

---

## 3. Decision: blue and red only

**D1 — the player's three kinds all use `ally` (blue); the AI's three all use `enemy` (red).**

Side reads perfectly and unambiguously, which is the property that matters most in a game where you must
see at a glance whose tank you are about to lose. The cost is that **type is no longer carried by the art
at all** — both sides' three kinds share one hull. D2 solves that.

Why not three silhouettes per side: the atlas is really **four silhouettes** (standard ×3 colours, heavy,
sniper, artillery), not a kind × side matrix, so a blue *and* red version of three distinct hulls does not
exist. I tested making one: hue-rotating `heavy` (gold) to blue and red gives usable if off-model cyan and
salmon tanks, but `sniper` is near-greyscale and `artillery` is dark and desaturated — there is no hue to
rotate and they come out unchanged. A consistent blue/red set of three silhouettes is an art job, not a
script. If that art ever appears, only `TankSkin` (§6) changes.

**D2 — type is read from the HUD. The board carries only a passive size cue.**

Nothing is stamped on the hull. Tapping a tank puts its full details in the HUD, which is where a player
who is unsure goes to be certain. The hull is also scaled per kind, so the board still reads at a glance
without being relied on for the answer:

| kind | hull width | HUD line |
|---|---|---|
| light | 0.55 × tile | `Light · HP 6/6 · Ammo 6/6 · Range 1` |
| medium | 0.72 × tile | `Medium · HP 10/10 · Ammo 5/5 · Range 1–2` |
| artillery | 0.64 × tile | `Artillery · HP 7/7 · Ammo 3/3 · Range 2–4` |

*Measured on a mock board* at real game size: the size cue makes light obviously smaller, but medium vs
artillery is too subtle to rely on — which is exactly why the HUD, not the board, is the source of truth.
The ammo pips already differ per kind (6 / 5 / 3) and give a second passive cue for free.

**D2a — tapping any tank inspects it, including enemies out of range.** This is the part that needs new
code, and without it the decision does not actually work. Today `BoardInteraction.tapTile` has no notion of
inspection:

- from `.idle`, a tap on an enemy tank is ignored;
- with a tank selected, a tap on an enemy **in range** aims at it, and a tap on an enemy **out of range**
  returns `[]` and changes nothing at all.

So there is currently no way to ask "what kind is that red tank?" unless it already happens to be in range
of the tank you have selected. With one shared hull per side that is precisely the confusion D1 introduces.

The fix is additive and does not touch the phase machine or the rules (§6): a tap that is not a legal aim,
move or confirmation sets `inspectedTankID` instead of being swallowed. The HUD then describes that tank,
and the board draws a **distinct inspection ring** on it — without which the player reads "Artillery, 7 HP"
with no idea which tank it refers to.

Which tank the HUD describes, in priority order: the aimed target → **the inspected tank** → the selected
tank → neither, in which case it falls back to today's `Blue 39 HP · Red 39 HP` totals. Enemy lines are
prefixed with the side so an inspected enemy is never mistaken for a selection, e.g.
`Red Artillery · HP 7/7 · Ammo 3/3 · Range 2-4`.

Inspecting beats the selection, which is not where this started. An earlier draft put the selection first;
built and looked at, that made the feature useless — asking "what is that red tank?" while your own tank is
selected is the main reason to inspect, and the HUD answered with the tank you had already picked. Anything
the player does with their own tank (select, re-point the move, cancel, end the turn) clears the
inspection, so the HUD comes straight back.

**D3 — keep the terrain as it is.** *Measured:* blue and red hulls read cleanly on today's placeholder
green `(0.62, 0.74, 0.45)` with no change. (An earlier draft of this doc required darkening the terrain —
that was only needed for the olive and brass sets, which D1 drops.)

**D4 — a contact shadow is optional polish.** A soft dark ellipse under each hull adds depth, but blue and
red already separate from the terrain without it. Do it in step 7 if it is wanted, not before.

**D6 — the inactive side dims to 0.8, not 0.55.** *Measured on device:* the placeholder shapes survived
0.55 alpha, but the painted art at that transparency blends into the green and the red side reads as a
muddy brown. 0.8 still says "not your turn" without destroying the art.

**D5 — scale by hull width, once per set.** Scale factor is `(kindHullWidth × tileSize) / idleHullWidth`,
measured from the atlas at load rather than hard-coded, and applied to **every** frame of that set so the
wreck and the muzzle flash do not change the tank's size. The barrel overhangs the tile; that is correct
and looks right.

The fractions in D2 came down from a first guess of 0.60 / 0.78 / 0.70 once it was on screen: the hull is
nearly square (45 px wide, 48 px tall for `ally`), so a 0.78-wide hull is 0.83 of a tile tall and the edge
rows lapped over the board frame. The HP bar and ammo pips moved out to ±0.44 of a tile for the same
reason — the art fills more of its tile than the placeholder square did.

---

## 4. Effects and UI icons

| game element | atlas source | notes |
|---|---|---|
| light tank shot | `effects.projectiles.bullet` | 2 frames, alternate while in flight |
| medium tank shot | `effects.projectiles.mediumShell` | 4 frames |
| artillery shot | `effects.projectiles.rocket` | 2 frames; longest, suits the arc |
| destruction | `effects.explosion` | 6 frames, replaces today's code-drawn circle |
| wreck smoke | `effects.smoke` | 6 frames, loops on a destroyed tile |
| kill scar | `effects.crater` | one static frame left on the tile |
| supply tile | `ui.crate` + existing code-drawn side-coloured ring | crate = ammo; ring carries the side |
| resupply flash | `ui.medkit` | pops and fades on the `.resupplied` event |
| selected tank | existing code-drawn ring | unchanged |

Projectiles are drawn pointing right, so rotate by `atan2(dy, dx)` from attacker to defender.

Parked: `laser`, and `flagGreen` / `flagRed` / `starBadge` / `shield` / `radar` / `rankChevron` /
`steelCrate`.

---

## 5. What must not change

- `TankGameCore` stays pure. None of this touches it.
- Everything still goes through `SpriteCatalog` (`tankNode`, `terrainNode`, `supplyNode`, `effectTexture`).
  No `SKSpriteNode(imageNamed:)` anywhere else.
- **A missing atlas must never crash or show a red X.** If `tank_atlas.png`/`.json` are absent or
  unparseable, the catalog falls back to today's placeholder shapes, exactly as it does for missing images
  now. This is what keeps the test target (no bundle resources) working.
- `Rules` is untouched. `BoardInteraction` gains exactly one additive thing — `inspectedTankID` (D2a) —
  set in branches that today return `[]` and do nothing. No new phase, no rules call, no change to what any
  existing tap does. Everything else here is presentation.

---

## 6. Code design

### New: `TankAtlas` (TankGameRendering)

Parses `tank_atlas.json` once and vends sub-textures of a single parent `SKTexture`, so the whole board
batches into few draw calls.

```swift
public struct AtlasFrame: Sendable {
    public let rect: CGRect        // pixels, top-left origin, as the JSON gives it
    public let anchor: CGPoint     // SpriteKit anchorPoint units, bottom-left origin
}

public enum TankAnimation: String, CaseIterable {   // the `up` row only
    case idle, move1, move2, move3, fire, destroyed
}

@MainActor
public final class TankAtlas {
    public init?(bundle: Bundle)                    // nil when the atlas is not in the bundle
    public func texture(_ set: String, _ animation: TankAnimation) -> (SKTexture, AtlasFrame)?
    public func effect(_ name: String, frame: Int) -> (SKTexture, CGSize)?
    public func icon(_ name: String) -> (SKTexture, CGSize)?
    /// Idle hull width in px, measured from the texture at load (D5).
    public func hullWidth(of set: String) -> CGFloat
}
```

**The one tricky bit:** `SKTexture(rect:in:)` takes a *normalised* rect with a **bottom-left** origin, while
the JSON is in pixels from the **top-left**. The conversion, which belongs in exactly one place and needs
its own unit test:

```swift
CGRect(x: x / imageWidth,
       y: 1 - (y + h) / imageHeight,
       width:  w / imageWidth,
       height: h / imageHeight)
```

### New: `TankSkin` — D1 and D2 in one table

```swift
public struct TankSkin: Sendable {
    public static func atlasSet(for side: Side) -> String          // .player -> "ally", .ai -> "enemy"
    public static func hullFraction(for kind: TankKind) -> CGFloat // .light -> 0.60, ...
}
```

One table, one test. When three-silhouette art exists, this is the only file that changes.

### Changed: `BoardInteraction` — inspection (D2a)

```swift
/// The tank the HUD should describe when nothing is selected or aimed at.
/// Set by a tap that would otherwise do nothing; cleared by selecting,
/// cancelling, committing or a new turn.
public private(set) var inspectedTankID: TankID?

/// Selected → aimed → inspected, for the HUD to describe.
public var describedTankID: TankID? { aimedTargetID ?? selectedTankID ?? inspectedTankID }
```

In `tapTile`, the two branches that currently return `[]` and change nothing — a tap on an enemy out of
range, and a tap from `.idle` on a tank that is not the current side's — set `inspectedTankID` instead.
Every existing tap keeps its current meaning; this only fills in the gaps.

### Changed: `HUDNode`

The selection line becomes a tank line driven by `describedTankID`, with the side named when the tank is
not the current side's (D2). Nothing else about the HUD changes.

### Changed: `SpriteCatalog`

Gains an optional `TankAtlas`. `tankNode(kind:side:)` returns an atlas-backed node when the atlas loaded
and a placeholder shape when it did not — same signature, so `TankSprite` and `BoardNode` do not care.
`effectTexture(_:)` gains the frame-sequence variants the animations need.

### Changed: `TankSprite`

- Holds the hull as an `SKSpriteNode` it can re-frame, plus the per-kind scale from D5.
- `play(_ animation: TankAnimation)` — sets texture, size and anchor together (F2).
- `setFacing(_:)` rotating the hull node by 0/90/180/270°, animated over ~0.12 s. AI tanks start facing
  down, as today.
- Adds an **inspection ring** (D2a), visually distinct from the selection ring — thinner, white, no pulse —
  so it is obvious which tank the HUD is describing.
- A destroyed tank currently sets `isHidden`. Instead: play `destroyed`, drop to ~0.6 alpha and a lower
  `zPosition`, and leave the wreck on the tile — the rules let a living tank drive over it, and it should
  park on top.

### Changed: `BoardNode`

- `.moved` → face the direction of travel, loop `move1→move2→move3→move2` while driving, back to `idle`.
- `.attacked`/`.counterattacked` → face the target, `fire` frame for ~0.12 s, then the projectile for that
  kind flies to the defender, then `explosion` if it was lethal.
- `.resupplied` → `medkit` icon pops and fades.
- Destruction leaves a `crater` on the terrain layer and a looping `smoke` on the effect layer.

---

## 7. Bundling the atlas

Ship `tank_atlas.png` and `tank_atlas.json` as **resources of the app target**. *Not* slices in
`Assets.xcassets` — slicing frames into individual images would throw away the JSON that is the source of
truth and lose the single-texture batching.

As built: the Xcode project uses a file-system-synchronized group for the `IOSTankBattle/` folder, so the
pair live in `IOSTankBattle/Art/` and are picked up with no project-file editing. They land in the bundle
root, which is where `Bundle.url(forResource:withExtension:)` looks. `docs/tank_atlas/` stays the authoring
copy and `IOSTankBattle/Art/` the shipped one, so re-exported art has to be copied across.

`SpriteCatalog` keeps taking a `Bundle`, so tests pass the test bundle (no atlas → placeholders) and the app
passes `.main`.

`AssetName` stays as it is for terrain and for the placeholder path. Tank art no longer comes from
`AssetName.tank(_:_:)`; `missingRequiredAssets()` should stop listing the six tank names once the atlas is
the source, or it will always report them missing.

---

## 8. Animation timings (first pass, all tunable)

| what | frames | timing |
|---|---|---|
| idle | `idle` | static |
| driving | `move1 → move2 → move3 → move2` | 0.08 s/frame while moving; the drive is already 0.10 s/tile |
| turning to face | — | 0.12 s rotation, before the drive starts |
| firing | `fire` | 0.12 s, then back to `idle` |
| projectile | 2–4 frames | 0.05 s/frame, flight time stays today's 0.22 s |
| explosion | 6 frames | 0.05 s/frame = 0.30 s total |
| wreck smoke | 6 frames | 0.12 s/frame, looping, 0.5 alpha |

---

## 9. Tests

The rendering target is already unit-testable, so this is not a leap of faith:

- `TankAtlas` parses the shipped JSON: 6 sets × 4 × 6 frames, every rect inside the image bounds.
- The pixel → normalised rect conversion, including the y flip, against hand-computed values.
- `TankSkin` maps both sides to distinct sets and all three kinds to distinct hull fractions.
- Inspection (D2a), which is the part with real logic in it:
  - tapping an out-of-range enemy sets `inspectedTankID` and leaves `phase` and the plan untouched;
  - tapping an enemy **in range** still aims, and does not merely inspect (the regression that would
    quietly break attacking);
  - `describedTankID` prefers aimed over selected over inspected;
  - selecting, cancelling, committing and `reset(to:)` all clear it.
- A missing or corrupt atlas yields `nil` and the catalog still returns placeholder nodes (today's tests
  must keep passing untouched — that is the regression guard).
- `TankSprite.play(_:)` sets size *and* anchor, not just texture (F2 is easy to regress).
- Per-kind scale from D5 gives a hull within a point of its `hullFraction × tileSize` for both sets.

---

## 10. Build order

1. ~~`TankAtlas` + JSON parsing + the rect conversion, with tests.~~ **Done.**
2. ~~Add the atlas to the app target; verify it loads on device.~~ **Done** — see §7.
3. ~~`TankSkin` + `SpriteCatalog` atlas path; placeholders still used when the atlas is absent.~~ **Done.**
4. ~~Per-kind hull sizing (D2), then inspection (D2a): `inspectedTankID`, the HUD tank line, the inspection
   ring.~~ **Done** — verified on the simulator: tapping a far red tank puts
   `Red Artillery · HP 7/7 · Ammo 3/3 · Range 2-4` in the HUD and rings that tank.
5. **Next:** `TankSprite.play` + facing; `BoardNode` move/fire animations. Everything above draws the
   static `idle` frame; the other five frames of each set are in the atlas and unused until this lands.
   **Checkpoint: a turn plays through.**
6. Projectiles, explosion, crater, smoke, resupply icon.
7. Supply tile crate; retire the "+" placeholder. Contact shadow (D4) if wanted.
8. Playtest on device, tune §8 timings and the hull fractions.

Steps 1–4 are independently useful and safe to stop after.

---

## 11. Parked, with the reason

- **`player`, `sniper`, `heavy`, `artillery` sets** — no blue/red counterpart exists and recolouring two of
  them does not work (§3). Revisit if three-silhouette team art appears, or for a third faction.
- **An `L`/`M`/`A` glyph stamped on each hull** — considered for type, dropped in favour of the HUD (D2).
  The atlas's own `rankChevron` / `starBadge` are the next thing to try if the HUD proves not to be enough,
  but they are gold and would need tinting, and they are mushy at ~10 pt.
- **`laser` projectile** and the seven unused UI icons — no unit or mechanic needs them in phase 1.
- **iPad** — needs a 2× atlas to look right (F3). Nothing in this design blocks it.
- **4-direction art** — the shipped rows are unusable (F1). A regenerated atlas could switch it on behind
  `TankAtlas.useDirectionRows`.
