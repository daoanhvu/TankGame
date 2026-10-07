import XCTest
@testable import TankGameCore

final class PositionTests: XCTestCase {
    func testManhattanDistance() {
        let a = Position(x: 1, y: 1)
        XCTAssertEqual(a.manhattanDistance(to: a), 0)
        XCTAssertEqual(a.manhattanDistance(to: Position(x: 4, y: 3)), 5)
        XCTAssertEqual(a.manhattanDistance(to: Position(x: 0, y: 0)), 2) // diagonal neighbour = 2
    }

    func testOrthogonalNeighborsHaveNoDiagonals() {
        let n = Set(Position(x: 5, y: 5).orthogonalNeighbors)
        XCTAssertEqual(n.count, 4)
        XCTAssertTrue(n.allSatisfy { $0.manhattanDistance(to: Position(x: 5, y: 5)) == 1 })
    }
}

final class TerrainTests: XCTestCase {
    func testMoveCosts() {
        XCTAssertEqual(Terrain.open.moveCost, 1)
        XCTAssertEqual(Terrain.trees.moveCost, 2)
        XCTAssertNil(Terrain.rocks.moveCost)
        XCTAssertNil(Terrain.water.moveCost)
        XCTAssertFalse(Terrain.rocks.isPassable)
        XCTAssertFalse(Terrain.water.isPassable)
    }
}

final class ConfigTests: XCTestCase {
    func testDefaultConfigIsValid() throws {
        try GameConfig.phase1Default.validate()
        XCTAssertEqual(GameConfig.phase1Default.army.count, 5)
        XCTAssertEqual(GameConfig.phase1Default.maxRounds, 40)
    }

    func testArtilleryCannotHitAdjacent() {
        let art = GameConfig.phase1Default.stats(for: .artillery)
        XCTAssertFalse(art.canReach(distance: 1))
        XCTAssertTrue(art.canReach(distance: 2))
        XCTAssertTrue(art.canReach(distance: 4))
        XCTAssertFalse(art.canReach(distance: 5))
    }

    func testJSONRoundTripUsesObjectKeys() throws {
        let data = try JSONEncoder().encode(GameConfig.phase1Default)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"artillery\":"), "Expected readable object keys, got: \(json)")
        let decoded = try GameConfig.load(fromJSON: data)
        XCTAssertEqual(decoded, .phase1Default)
    }

    func testInvalidConfigRejected() {
        var cfg = GameConfig.phase1Default
        cfg.tankStats[.medium] = nil
        XCTAssertThrowsError(try cfg.validate())

        cfg = .phase1Default
        cfg.tankStats[.light] = TankStats(movePoints: 5, minRange: 3, maxRange: 1,
                                          maxHP: 6, damage: 3, maxAmmo: 6)
        XCTAssertThrowsError(try cfg.validate())
    }
}

final class MapTests: XCTestCase {
    func testCrossingMapParses() throws {
        let map = try GameMap(ascii: Maps.crossing)
        XCTAssertEqual(map.width, 12)
        XCTAssertEqual(map.height, 10)
        XCTAssertEqual(map.supplyTiles[.ai], Position(x: 6, y: 0))
        XCTAssertEqual(map.supplyTiles[.player], Position(x: 5, y: 9))
        XCTAssertEqual(map.spawnTiles[.player]?.count, 5)
        XCTAssertEqual(map.spawnTiles[.ai]?.count, 5)
        XCTAssertEqual(map.terrain(at: Position(x: 2, y: 2)), .rocks)
        XCTAssertEqual(map.terrain(at: Position(x: 6, y: 3)), .water)
        XCTAssertNil(map.terrain(at: Position(x: 12, y: 0)))
    }

    /// The map and the spawn order must be fair: rotating by 180° swaps the sides.
    func testCrossingMapIsRotationallySymmetric() throws {
        let map = try GameMap(ascii: Maps.crossing)
        func rotated(_ p: Position) -> Position {
            Position(x: map.width - 1 - p.x, y: map.height - 1 - p.y)
        }
        for y in 0..<map.height {
            for x in 0..<map.width {
                let p = Position(x: x, y: y)
                XCTAssertEqual(map.terrain(at: p), map.terrain(at: rotated(p)), "Asymmetry at \(p)")
            }
        }
        XCTAssertEqual(rotated(map.supplyTiles[.player]!), map.supplyTiles[.ai])
        let playerSpawns = map.spawnTiles[.player]!
        let aiSpawns = map.spawnTiles[.ai]!
        for (p, a) in zip(playerSpawns, aiSpawns) {
            XCTAssertEqual(rotated(p), a, "Army slot spawns are not mirrored")
        }
    }

    func testCanEnterRespectsTerrainAndSupplyOwnership() throws {
        let map = try GameMap(ascii: Maps.crossing)
        let playerSupply = map.supplyTiles[.player]!
        let aiSupply = map.supplyTiles[.ai]!
        XCTAssertTrue(map.canEnter(playerSupply, side: .player))
        XCTAssertFalse(map.canEnter(playerSupply, side: .ai))
        XCTAssertTrue(map.canEnter(aiSupply, side: .ai))
        XCTAssertFalse(map.canEnter(aiSupply, side: .player))
        XCTAssertFalse(map.canEnter(Position(x: 2, y: 2), side: .player)) // rocks
        XCTAssertTrue(map.canEnter(Position(x: 8, y: 2), side: .player))  // trees
        XCTAssertFalse(map.canEnter(Position(x: -1, y: 0), side: .player)) // off map
    }

    func testInvalidMapsAreRejected() {
        let cases: [String: String] = [
            "ragged row":       "Sa\n..\n.Ps",
            "unknown char":     "S.?\nPas",
            "two supplies":     "SSs\nPa.",
            "missing AI supply":"S..\nPa.",
            "no AI spawns":     "S.s\nP..",
            "empty":            "",
        ]
        for (name, text) in cases {
            XCTAssertThrowsError(try GameMap(ascii: text), name)
        }
    }
}

final class GameStateTests: XCTestCase {
    private func makeGame() throws -> GameState {
        try GameState.newGame(map: GameMap(ascii: Maps.crossing))
    }

    func testNewGameSetup() throws {
        let state = try makeGame()
        XCTAssertEqual(state.tanks.count, 10)
        XCTAssertEqual(state.currentSide, .player)
        XCTAssertEqual(state.round, 1)
        XCTAssertEqual(state.status, .ongoing)
        XCTAssertFalse(state.isOver)

        for (index, tank) in state.tanks.enumerated() {
            XCTAssertEqual(tank.id, index, "Tank id must equal its array index")
            let s = state.stats(of: tank)
            XCTAssertEqual(tank.hp, s.maxHP)
            XCTAssertEqual(tank.ammo, s.maxAmmo)
            XCTAssertTrue(state.map.spawnTiles[tank.side]!.contains(tank.position))
        }
        for side in Side.allCases {
            XCTAssertEqual(state.aliveTanks(of: side).map(\.kind), GameConfig.phase1Default.army)
        }
        // 2*6 + 2*10 + 7
        XCTAssertEqual(state.totalHP(of: .player), 39)
        XCTAssertEqual(state.totalHP(of: .ai), 39)
    }

    func testSpawnCountMustMatchArmy() throws {
        let tinyMap = try GameMap(ascii: "S.Pa.s")
        XCTAssertThrowsError(try GameState.newGame(map: tinyMap))
    }

    func testDestroyedTanksAreIgnoredByQueries() throws {
        var state = try makeGame()
        let victim = state.tanks[0]
        state.tanks[0].hp = 0

        XCTAssertNil(state.tank(at: victim.position))
        XCTAssertEqual(state.aliveTanks(of: .player).count, 4)
        XCTAssertEqual(state.totalHP(of: .player), 39 - 6)
        XCTAssertNotNil(state.tank(0), "Destroyed tanks stay addressable by id")
    }

    func testStateIsAValueType() throws {
        let original = try makeGame()
        var copy = original
        copy.tanks[0].hp = 1
        XCTAssertNotEqual(original.tanks[0].hp, 1, "AI simulations must not mutate the real game")
    }

    func testActionCodableRoundTrip() throws {
        let actions: [Action] = [
            .pass,
            .command(TankCommand(tankID: 2, destination: Position(x: 3, y: 4))),
            .command(TankCommand(tankID: 4, destination: Position(x: 9, y: 9), targetID: 7)),
        ]
        let data = try JSONEncoder().encode(actions)
        XCTAssertEqual(try JSONDecoder().decode([Action].self, from: data), actions)
    }
}
