# TankGameCore

Pure-Swift rules engine for the turn-based tank game (no UIKit/SpriteKit).

## Run the tests
- Xcode: File > Open > select this folder (or `Package.swift`), then Cmd+U.
- Terminal: `swift test`

## Status
- [x] Task 1 - Data models (`Position`, `Terrain`, `TankKind`/`TankStats`,
      `GameConfig`, `Tank`, `GameMap`, `GameState`, `Action`)
- [ ] Task 2 - Reachable tiles (Dijkstra)
- [ ] Task 3 - Attackable targets
- [ ] Task 4 - Combat and counterattack
- [ ] Task 5 - Supply tile
- [ ] Task 6 - Turn flow
- [ ] Task 7 - Win/end conditions
- [ ] Task 8 - Rule tests

## Map format (see `Maps.swift`)
    .  open    T  trees    R  rocks    W  water
    S  player supply       s  AI supply
    P  player spawn        a  AI spawn
