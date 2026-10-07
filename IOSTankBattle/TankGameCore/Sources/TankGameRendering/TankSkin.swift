import CoreGraphics
import TankGameCore

/// Which atlas art a tank wears, and how big it is drawn.
///
/// Phase 1 uses two sets only: blue for the player, red for the AI, for all
/// three kinds (`docs/sprite_design.md` D1). The atlas is really four
/// silhouettes in six colours rather than a kind × side matrix, so a blue AND
/// red version of three distinct hulls does not exist, and two of the four
/// cannot be recoloured into one (they are near-greyscale — there is no hue to
/// rotate).
///
/// Type is therefore read from the HUD, not from the hull (D2). The size
/// difference here is a passive cue, not the answer: light is obviously
/// smaller, but medium and artillery are close on purpose — the HUD is what
/// settles it.
///
/// If three-silhouette team art ever arrives, this is the only file that
/// changes.
public enum TankSkin {

    public static func atlasSet(for side: Side) -> String {
        switch side {
        case .player: return "ally"    // blue
        case .ai:     return "enemy"   // red
        }
    }

    /// Hull width as a fraction of a tile. The barrel overhangs, which is
    /// correct for top-down art — but the hull itself is nearly square, so
    /// these stay well under 1 or a tank laps over its tile and, on the edge
    /// rows, over the board frame.
    public static func hullFraction(for kind: TankKind) -> CGFloat {
        switch kind {
        case .light:     return 0.55
        case .medium:    return 0.72
        case .artillery: return 0.64
        }
    }
}
