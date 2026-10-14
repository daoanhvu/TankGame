import Foundation

/// Built-in handmade maps.
public enum Maps {

    /// 12 x 18, made in the Tiled editor from 92 x 92 tiles: grassland with a
    /// lake and a village near each corner, rocky outcrops and stands of
    /// forest, all of them impassable. Red starts in the top-right corner,
    /// Blue in the bottom-left.
    ///
    /// The supply tiles and the spawns are 180° turns of each other — (x, y)
    /// for Red is (11 - x, 17 - y) for Blue — so each army stands the same way
    /// round its depot. The terrain is only roughly symmetric.
    ///
    /// Returns the tile layers too, for the renderer to draw; the rules only
    /// ever see `map`.
    public static func twinLakes() throws -> (map: GameMap, tiled: TiledMap) {
        let tiled = try loadTiled("tank921218")
        let map = try GameMap(
            tiled: tiled,
            supplyTiles: [.ai: Position(x: 9, y: 0), .player: Position(x: 2, y: 17)],
            // Army order: light, light, medium, medium, artillery. Lights up
            // front, the artillery tucked in behind beside the depot.
            spawnTiles: [
                .ai: [Position(x: 8, y: 2), Position(x: 10, y: 2), Position(x: 8, y: 1),
                      Position(x: 10, y: 1), Position(x: 10, y: 0)],
                .player: [Position(x: 3, y: 15), Position(x: 1, y: 15), Position(x: 3, y: 16),
                          Position(x: 1, y: 16), Position(x: 1, y: 17)],
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
