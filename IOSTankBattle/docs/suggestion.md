# Making Tank Strategy Compelling — A Player's Review

**Reviewed:** the build as of 2026-10-10 — Crossing map (12×10), 5 v 5, one action per tank per turn,
greedy AI playing Red.
**Perspective:** a competitive turn-based tactics player (Advance Wars, Into the Breach, Fire Emblem,
XCOM). The question I asked of every system: *does this create an interesting decision, or does it
have one right answer?*
**Method:** read the rules and the code, then measured the game with 300 AI-vs-AI self-play matches
via `AIMatch` (60 detailed + 240 for win rates, with `jitter` so matches differ).

> **Caveat on the numbers.** Self-play is the greedy AI playing itself, and it is not a strong player —
> it uses light tanks especially badly. Treat the figures as signals that point at a problem, not as
> proof. Where it matters I back them with the stat arithmetic, which holds whoever is playing.

---

## TL;DR — the five changes that matter most

| # | Change | Why it matters | Cost |
|---|---|---|---|
| 1 | **Add a reason to move: capture points** (§5) | Pure attrition plus perfect information rewards waiting. A human will learn to sit under their artillery and let the AI walk in, and once that clicks the game is solved. | Medium |
| 2 | **Artillery: move OR fire, not both** (§3.2) | Artillery deals **56%** of all damage with 1 tank in 5. Setup time is the classic counterplay and gives the other units a job. | Small (rule) |
| 3 | **Give the light tank a role** (§3.1) | **87%** of light tanks die, and they deal **under 3%** of the damage. One unit in five is currently fodder. | Small (numbers) |
| 4 | **Make PASS safe: rename it END TURN and confirm when units are unused** (§7.1) | Since the turn change, one mistap forfeits up to five actions. It is the single most rage-inducing thing in the build. | Tiny |
| 5 | **Danger-zone overlay** (§7.2) | The enemy-range toggle is the most important quality-of-life feature in the genre — and `ThreatMap` already computes it. | Small |

Then the polish that makes it *feel* good (§7), and the modes that make people come back (§8).

---

## 1. What already works — keep it

- **The damage preview includes the counterattack.** With no randomness, the preview *is* the
  outcome, so every attack is a solvable puzzle. This is the game's best feature: it makes it a
  thinking game rather than a dice game.
- **There is a real rock-paper-scissors triangle in the numbers** (see §2.2): light beats artillery,
  artillery beats medium, medium beats light. Most indie tactics games never get that far. The job is
  to make every edge of the triangle actually hold.
- **One action per tank per turn** turned every turn into a sequencing puzzle: who moves first, who
  screens whom, who finishes the kill. It also cut matches from ~31 rounds to ~14–18 — about the
  right length for a phone session.
- **The supply depot is a second thing to think about** besides "shoot the nearest tank". It is too
  strong right now (§3.3), but the idea is good.
- **The board reads instantly.** Blue against red, one shared unit card, a clear status line.

---

## 2. What the numbers say

### 2.1 Self-play findings

| Finding | Data | What a player feels |
|---|---|---|
| **The side that moves second wins more** | Red 128 – Blue 93 (19 draws) over 240 matches: **58%** of decisive games | Moving first means walking into range first. In round 1 Blue advances and Red's artillery shells a Blue light for 5. The player *always* moves first, so the human starts every match at a disadvantage. |
| **Light tanks are fodder** | 209 of 240 lights destroyed (**87%**); **2.8%** of all damage dealt | "Why do I even have these?" |
| **Artillery carries the game** | **56%** of all damage, from 1 tank in 5; never takes a counterattack at range 3–4 | Whoever uses their artillery better wins; the rest of the army is support staff. |
| **The counterattack rarely fires** | Only **13%** of attacks draw one | The signature rule is mostly invisible, because the best attacks are the ones that dodge it. |
| **The depot is the strongest action in the game** | **11.5 full refills per match** | Trading damage near your own depot is free, so the fight degenerates into shuttle runs. |
| **There is no opening** | First blood in round **1.1** on average | The map is small enough that the armies collide immediately — there is no scouting or manoeuvring phase. |
| **The round limit no longer matters** | Decided on HP in 2 of 60 matches | Fine, but it means the end condition is purely "kill everything". |

### 2.2 The matchup table (attacker → defender: damage dealt / counter taken)

This is pure arithmetic from the stat table, so it holds for any player.

| Attacker ↓ / Defender → | Light (6 HP) | Medium (10 HP) | Artillery (7 HP) |
|---|---|---|---|
| **Light** (range 1, dmg 3) | 3 / 3 | 3 / **4** ✗ | 3 / **0** ✓ |
| **Medium** (range 1–2, dmg 4) | 4 / 3 at range 1 · 4 / **0** at range 2 ✓ | 4 / 4 | 4 / 0 at range 1 · 4 / 5 at range 2 |
| **Artillery** (range 2–4, dmg 5) | 5 / **0** ✓ | 5 / 4 at range 2 · 5 / **0** at range 3–4 ✓ | 5 / 5 |

Shots to kill: **artillery kills everything in 2.** A medium needs 3 shots from another medium and 4
from a light. A light needs **3** shots to kill the artillery it is supposed to counter.

**Why the triangle breaks.** The light's one good matchup is the artillery, but the artillery's range
of 2–4 means it shoots first while the light closes, and a single 5-damage shell leaves a 6-HP light
on 1 HP. So the light loses the tempo race to the very unit it exists to hunt, and its other two
matchups are a trade-down and a coin flip.

---

## 3. Balance — fixes that are mostly numbers

Every item below is a `GameConfig` value or a small change in `Rules`. Re-run self-play after each one
(see §10 for targets).

### 3.1 Give the light tank a job

The light has the best mobility in the game and nothing to spend it on. Two options; try A first.

**A — numbers only (recommended to start):** damage **3 → 4**.
- vs artillery: kills in **2** shots instead of 3 → the light wins its race against the artillery.
- vs medium: 4 out / 4 back → a fair trade instead of a losing one.
- vs light: still 2 shots each.

**B — a mechanic, if A is not enough: "Charge".** A light that moved at least 3 tiles before firing
takes no counterattack. Speed becomes damage, flanking becomes a skill, and the 13% counterattack
rate becomes a decision you play around instead of noise.

The real fix for the light is **objectives** (§5): a 5-move unit is the obvious capper, and capping
needs no damage at all.

### 3.2 Artillery: move OR fire

This is Advance Wars' indirect-fire rule, and it exists for this exact problem. Artillery that has to
stop to deploy:
- can't roll up and shell someone in round 1 (which is what happens now),
- gives lights a turn to close in, which repairs the triangle,
- turns artillery placement into a real decision ("where do I set up?") instead of a free reflex.

⚠ **This changes the frozen spec**, which currently says "move then attack… *artillery included*".
That's your call, but I'd make it.

Fallback if you want to keep move-and-fire: max range **4 → 3**. That gives mediums a counterattack
window at range 2–3 and makes the artillery commit closer.

### 3.3 Nerf the depot: partial heal

A full HP + full ammo refill, every time a tank re-enters, makes damage near your own lines
meaningless and creates the shuttle loop (step off, step on, full health).

Recommended: **arriving restores all ammo, but only +50% of max HP** (light +3, medium +5,
artillery +3–4). Optional, and stronger: **arriving ends that tank's action — no refill-then-fire.**
Resupplying then costs tempo, which is what makes it a decision.

### 3.4 Fix the first-move disadvantage — with objectives, not numbers

The data says moving first loses. Look closer, though: the reason is that the *greedy AI* always
advances, and advancing first gets you shot. A human will learn the opposite lesson within a few
games — **don't move, let the AI walk into your artillery.** That is two problems in one:

1. The best opening is to wait. Two good players who both know it will stare at each other.
2. The AI is trivially exploitable by baiting (already noted as a known limit in `CLAUDE.md`).

Stat tweaks can't fix "waiting is optimal". Something on the map has to be worth moving for. That's §5.

### 3.5 Round limit

At ~14–18 rounds per match, 40 is generous. **With capture points, set it to 15–20** and decide it on
points; the HP tie-break becomes a rare fallback rather than a strategy.

---

## 4. Replayability — make every match different

### 4.1 Maps with identities (already milestone 4; here's how to make each one count)

Every map should change **which unit is king**:

| Map concept | Shape | Who it favours |
|---|---|---|
| **Crossing** (current) | Diagonal river, two fords | Balanced |
| **Bridgehead** | One narrow bridge in the middle, depots on the far banks | Artillery covering the choke; lights for flanking fords |
| **Woodland** | ~40% trees (cost 2) | Mediums — slow ground blunts both light speed and the artillery's approach |
| **Open Steppe** | Almost no terrain, wide | Lights and artillery; terrifying, fast |
| **Twin Depots** | Each side has a depot near the centre, contested | Forces early fights over sustain |

Keep 180° symmetry, and **move the depots forward** on at least one map so resupply becomes a risk.

### 4.2 Army draft (high value, low cost)

`GameConfig.army` is already an array. Let players **buy their five tanks from a points budget** —
e.g. light 2, medium 3, artillery 4, budget 14. "Three artillery and two lights" against "four mediums"
is a completely different match, and pre-game composition is where a lot of a tactics game's depth
lives. The AI can start by picking one of a few fixed compositions at random.

### 4.3 Terrain that matters (phase 2 — currently out of scope)

Trees are just slow right now: there is never a reason to *stand* in them. **Trees: −1 damage taken**
would make positioning matter on every turn. This is the cheapest depth you can add, but it's listed
as out of scope for phase 1, so park it for phase 2.

**Wrecks:** a destroyed tank leaves a wreck tile that blocks movement (or gives cover). The map
changes as the fight goes on, and kills get a lasting visual payoff — that's good for feel too.

---

## 5. Objectives — the biggest lever in the game

Right now the only goal is "kill everything", which has three consequences: waiting is optimal (§3.4),
speed is worthless (§3.1), and the end condition never varies.

**Recommended: capture points.**
- 1–3 neutral **outposts** per map (a new ASCII glyph, e.g. `O`).
- An outpost belongs to whoever last ended a turn with a tank on it and none of the enemy's adjacent.
- At the end of each round, each side scores 1 point per outpost held.
- **First to N points wins** (N ≈ 10), or most points at the round limit. Annihilation still wins
  outright.

What this buys:
- **Waiting loses**, so the turtling problem goes away.
- **Lights get a job**: a 5-move unit grabs a far outpost on round 1.
- **The AI stops being baitable** — it has somewhere to go besides your kill zone. In `GreedyEvaluator`,
  an outpost is one more approach target.
- **Every match has a clock and a scoreboard**, which is what creates late-game tension and comebacks.

Implementation fits the architecture cleanly: the terrain glyph goes in `GameMap`, the owner and score
in `GameState`, and the scoring in `Rules.advanceTurn` at the round boundary.

Alternatives, for variety later: **Depot raid** (destroy the enemy depot), **VIP** (protect one
commander tank; lose it, lose the match), **Hold out** (survive N rounds against a bigger army — a
great campaign mission type).

---

## 6. A better opponent

Against the AI is the *whole game* in phase 1, so the AI's personality *is* the game's personality.

1. **Difficulty selector — mostly built already.** `AIWeights.reckless` / `.standard` / `.cautious`
   plus `jitter` already exist. Ship it as **Recruit / Veteran / Commander**. Add a 2-ply search
   (already on the roadmap) as **Hard** later.
2. **Stop the bait.** Even before objectives, add a "patience" term: don't step into a tile the
   player's artillery covers unless the attack you get there is worth it. Pros find exploits within
   an hour; this is the first one they'll find.
3. **Focus fire.** The AI scores each tank alone. A bonus for attacking a target a teammate can finish
   this same turn (this is cheap now that the whole army acts in one turn) makes it feel coordinated,
   and coordinated enemies are scary.
4. **Character.** Give the AI a commander with a name, a portrait and one line per event ("Your flank
   is open, Lieutenant."). It costs nothing and turns "the computer" into a rival.

---

## 7. Game feel — what makes it *entertaining*

### 7.1 Fix the dangerous button (do this first)

Since the turn change, **PASS forfeits every unused tank's action**. One accidental tap ends a turn
with three tanks unmoved.
- Rename it **END TURN**.
- If any tank is still awaiting orders, the first tap turns it into "END TURN? 3 UNITS IDLE" and the
  second tap confirms.
- Add a **NEXT UNIT** button (or tap empty ground) that cycles through tanks still awaiting orders.

### 7.2 Danger-zone overlay

Hold a button, or long-press an enemy, to tint every tile the enemy can hit next turn. In this genre
that's the difference between "I lost because I'm bad" and "I lost because I didn't know". The data
is already there: `ThreatMap(threatTo: .player, in: state)` is exactly this overlay, and for one enemy,
its reachable tiles plus its range band.

### 7.3 Juice — cheap, and huge for feel

| Effect | Notes |
|---|---|
| **Floating damage numbers** | Already planned for milestone 4. Make them big, and make kills red. |
| **Haptics** | `UIImpactFeedbackGenerator`: light tap on select, heavy thump on a hit, a rumble on a kill. Almost free on iPhone, and it feels much better. |
| **Screen shake on kills** | 2–3 points, 0.15s. Never on a miss (there are none) or a move. |
| **Muzzle flash + recoil** | The hull kicks back half a tile-pixel; the artillery shell arcs instead of flying straight. |
| **Sound** | A distinct cannon voice per type (light pop, medium crack, artillery boom), engine idle, a clank on resupply. |
| **Turn banner** | "RED TURN" sweeps across for 0.6s. It fixes "wait, whose turn is it?" |
| **AI fast-forward** | Red's turn is now five animations. A 2× / skip toggle is mandatory — nobody wants to watch it for the 30th time. |

### 7.4 Readability

- Show the **counterattack preview on the defender's card** too, not just the status line — players
  look at the card.
- A **"kill" badge on targets you can finish this action** (preview says `targetDestroyed`). It's the
  most satisfying highlight in the genre.
- **A match recap screen**: damage per unit, an MVP tank, the turning point. Players love to see why
  they won.

---

## 8. Reasons to come back

1. **Tactics puzzles — the most distinctive idea here.** The engine is deterministic with perfect
   information, which is exactly what a puzzle needs. "Win this turn" or "destroy the artillery
   without losing a tank", authored as an ASCII map plus a tank list, the same format the tests
   already use. A **daily puzzle** is a retention engine that costs one tiny map a day, and the
   self-play harness can verify that each puzzle is solvable.
2. **Campaign (phase 2):** 10–15 handcrafted missions with asymmetric starts and varied objectives
   (hold out, escort, assault a fortified depot), plus **3 stars per mission** (win / no losses /
   under N rounds).
3. **Cosmetic unlocks:** `TankSkin` already separates art from logic, so camo patterns for stars are
   a natural fit.
4. **Async multiplayer (later):** turn-based with perfect information is the ideal Game Center
   turn-based match. Same rules, no AI needed, and a friend is the best opponent there is.

---

## 9. New units (later, and sparingly)

The roster of three is a strength — every unit needs a clear identity before you add a fourth. Once
the triangle holds, the best candidates:
- **Repair truck:** no gun; heals an adjacent ally +3 per turn. This lets you nerf the depot (§3.3)
  without making healing scarce, and it creates a high-value target to protect.
- **Tank destroyer:** high damage against mediums, can't counterattack. A specialist that punishes
  medium-heavy drafts (§4.2).

---

## 10. Suggested order of work

| Phase | Work | Proves it |
|---|---|---|
| **A — this week** (numbers and tiny rules) | END TURN confirm + NEXT UNIT; artillery move-or-fire; depot +50% HP; light damage 4; danger-zone overlay | Re-run self-play against the targets below |
| **B — milestone 4 polish** | Juice table (§7.3), sound, haptics, AI fast-forward, difficulty selector, 3 maps with identities | First playtest sessions with real players |
| **C — the depth patch** | Capture points + scoring HUD; AI goes for objectives; round limit to ~18 | Turtling stops being optimal |
| **D — retention** | Daily puzzles, campaign + stars, army draft, recap screen | People come back tomorrow |
| **Later** | Terrain defence, wrecks, fog of war, new units, async multiplayer | — |

### Balance targets for self-play

`AIMatch.tally` already gives win rates. I measured the rest with a throwaway harness that replays
`AIMatch.takeAction` and counts `GameEvent`s. Make that a permanent "balance report" test and check
it after every balance change:

| Metric | Now | Target |
|---|---|---|
| Second-mover win rate | 58% | 45–55% |
| Damage share per unit type | light 3% / medium 41% / artillery 56% | each 20–45% |
| Light tank loss rate | 87% | under 65% |
| Attacks that draw a counterattack | 13% | 20–35% (the mechanic should be felt) |
| Depot refills per match | 11.5 | 3–6 |
| Round of first blood | 1.1 | 2–4 (room for an opening) |
| Matches decided on HP at the limit | 3% | under 10% (or 0 with points) |

---

*One line to remember:* the game already has what tactics players want — perfect information, a
damage preview you can trust, a unit triangle. What's missing is a **reason to move** and a **job for
every unit**. Add those two and the rest is polish.
