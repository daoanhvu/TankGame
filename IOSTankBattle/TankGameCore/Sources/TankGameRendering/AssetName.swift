import TankGameCore

/// Single source of truth for art file names.
///
/// Convention: `<category>_<variant>[_<side>]`, lowercase, underscores.
/// Images with these names go in the app's asset catalog (Assets.xcassets).
/// Replacing the art = replacing images with the same names. No code changes.
///
/// Orientation rule: every tank sprite (and barrel) is drawn FACING UP (north).
/// The renderer rotates AI tanks to face down at game start.
public enum AssetName {

    /// e.g. `tank_light_player`, `tank_artillery_ai`
    public static func tank(_ kind: TankKind, _ side: Side) -> String {
        "tank_\(kind.rawValue)_\(side.rawValue)"
    }

    /// Optional separate barrel so it can rotate toward a target,
    /// e.g. `tank_medium_player_barrel`. If missing, the hull sprite is used alone.
    public static func tankBarrel(_ kind: TankKind, _ side: Side) -> String {
        tank(kind, side) + "_barrel"
    }

    /// e.g. `terrain_open`, `terrain_trees`, `terrain_rocks`, `terrain_water`
    public static func terrain(_ terrain: Terrain) -> String {
        "terrain_\(terrain.rawValue)"
    }

    /// Drawn on top of the open-ground tile, e.g. `supply_player`, `supply_ai`
    public static func supply(_ side: Side) -> String {
        "supply_\(side.rawValue)"
    }

    public enum Effect: String, CaseIterable {
        case explosion
        case muzzleFlash = "muzzle_flash"
        case projectile
    }

    /// e.g. `fx_explosion`, `fx_muzzle_flash`, `fx_projectile`
    public static func effect(_ effect: Effect) -> String {
        "fx_\(effect.rawValue)"
    }

    /// Every loose image the game needs. Doubles as the asset list for a
    /// designer.
    ///
    /// Tank hulls are NOT here: they come from the sprite sheet via `TankAtlas`
    /// and `TankSkin`, not from individually named images, so listing them
    /// would report six assets as permanently missing. `tank(_:_:)` stays for
    /// the named-image fallback and for a future designer hand-off.
    public static var required: [String] {
        var names: [String] = []
        names += Terrain.allCases.map(terrain)
        names += Side.allCases.map(supply)
        names += Effect.allCases.map(effect)
        return names
    }

    /// Nice to have; the game looks fine without them.
    public static var optional: [String] {
        TankKind.allCases.flatMap { kind in
            Side.allCases.map { side in tankBarrel(kind, side) }
        }
    }
}
