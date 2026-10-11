import Foundation

/// Built-in handmade maps.
public enum Maps {

    /// 16 x 20, made in the Tiled editor from 64 x 64 tiles: open grassland
    /// broken up by two lakes, villages, rocky outcrops and blocks of forest,
    /// all of them impassable. Red starts in the top-right corner, Blue in the
    /// bottom-left.
    ///
    /// Not 180°-symmetric like `crossing`; the two corners are instead mirrors
    /// of each other about their own supply tiles — (x, y) for Red is
    /// (16 - x, 19 - y) for Blue — so each army stands the same way round its
    /// depot.
    ///
    /// Returns the tile layers too, for the renderer to draw; the rules only
    /// ever see `map`.
    public static func greenfield() throws -> (map: GameMap, tiled: TiledMap) {
        let tiled = try loadTiled("greenfield-2")
        let map = try GameMap(
            tiled: tiled,
            supplyTiles: [.ai: Position(x: 14, y: 0), .player: Position(x: 2, y: 19)],
            // Army order: light, light, medium, medium, artillery. Lights up
            // front, the artillery tucked into the corner beside the depot.
            spawnTiles: [
                .ai: [Position(x: 11, y: 1), Position(x: 10, y: 0), Position(x: 12, y: 0),
                      Position(x: 13, y: 0), Position(x: 15, y: 0)],
                .player: [Position(x: 5, y: 18), Position(x: 6, y: 19), Position(x: 4, y: 19),
                          Position(x: 3, y: 19), Position(x: 1, y: 19)],
            ])
        return (map, tiled)
    }

    /// A `.tmj` from this package's resources, with the `.tsj` tilesets it
    /// refers to, which sit beside it.
    private static func loadTiled(_ name: String) throws -> TiledMap {
        func resource(_ file: String) throws -> Data {
            let url = URL(fileURLWithPath: file)
            guard let found = Bundle.module.url(forResource: url.deletingPathExtension().lastPathComponent,
                                                withExtension: url.pathExtension) else {
                throw GameModelError.invalidMap("\(file) is missing from the bundle")
            }
            return try Data(contentsOf: found)
        }
        return try TiledMap(json: try resource("\(name).tmj"), externalTileset: resource)
    }

    /// 12 x 10, 180°-rotationally symmetric for fairness. Player starts at the
    /// bottom, AI at the top.
    public static let crossing = """
        ..aaa.s.aa..
        ............
        ..RR....TT..
        .TT...WW....
        ......WW..R.
        .R..WW......
        ....WW...TT.
        ..TT....RR..
        ............
        ..PP.S.PPP..
        """
}
