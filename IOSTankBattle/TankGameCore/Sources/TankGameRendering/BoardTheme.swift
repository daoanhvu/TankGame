import SpriteKit
import TankGameCore

/// Colors, type and sizes for the parts the game draws in code rather than as
/// art: the frame around the field, tile highlights, HP bars, ammo pips,
/// selection rings, the HUD, the unit cards and the command bar.
///
/// Art assets never cover these, so this stays valid when the placeholder
/// shapes are replaced by a real tile set. The look follows
/// `docs/ScreenDesign.png`: a dark olive field manual, amber for the things
/// that change, cream for the things that are read.
public struct BoardTheme: Sendable {

    /// Which of the three button looks a control wears. Destructive and
    /// confirming actions should not look the same as navigation.
    public enum ButtonStyle: Sendable {
        /// Firing: the one button that spends a turn aggressively.
        case danger
        /// Committing a move, ending a turn.
        case confirm
        /// Everything else (cancel, pass, rematch).
        case neutral
    }

    /// Fill, bevel and text for one button look.
    public struct ButtonPalette: Sendable {
        public var fill: SKColor
        public var stroke: SKColor
        public var text: SKColor

        public init(fill: SKColor, stroke: SKColor, text: SKColor) {
            self.fill = fill
            self.stroke = stroke
            self.text = text
        }
    }

    // MARK: - Board overlays

    public var moveHighlight = SKColor(red: 0.42, green: 0.72, blue: 0.95, alpha: 0.38)
    public var attackHighlight = SKColor(red: 0.90, green: 0.33, blue: 0.27, alpha: 0.42)
    public var selectionRing = SKColor(red: 0.90, green: 0.76, blue: 0.30, alpha: 1.00)
    public var pathHint = SKColor(red: 0.90, green: 0.86, blue: 0.72, alpha: 0.80)
    public var hpBarBackground = SKColor(white: 0.0, alpha: 0.55)
    public var hpBarFill = SKColor(red: 0.52, green: 0.76, blue: 0.35, alpha: 1.00)
    public var hpBarLowFill = SKColor(red: 0.88, green: 0.45, blue: 0.22, alpha: 1.00)
    public var ammoPip = SKColor(red: 0.91, green: 0.87, blue: 0.75, alpha: 0.95)
    public var ammoPipEmpty = SKColor(white: 1.0, alpha: 0.20)

    // MARK: - Scene and frame

    /// Behind everything: the table the board sits on.
    public var sceneBackground = SKColor(red: 0.055, green: 0.078, blue: 0.055, alpha: 1)
    /// The surface the field sits on, filling the gap a board that is limited
    /// by screen WIDTH leaves above and below itself.
    public var fieldBackground = SKColor(red: 0.094, green: 0.118, blue: 0.090, alpha: 1)
    /// The plate the field is set into.
    public var framePlate = SKColor(red: 0.098, green: 0.125, blue: 0.094, alpha: 1)
    /// The plate's dark outer edge and the shadow under the board.
    public var framePlateEdge = SKColor(red: 0.039, green: 0.055, blue: 0.039, alpha: 1)
    /// The lit top edge of the bevel.
    public var frameHighlight = SKColor(white: 1.0, alpha: 0.10)
    /// Amber: the accent on rules, counters and the active control.
    public var frameAccent = SKColor(red: 0.902, green: 0.765, blue: 0.302, alpha: 1)
    /// Kept for the slim frame's corner ticks.
    public var frameRivet = SKColor(red: 0.231, green: 0.267, blue: 0.220, alpha: 1)

    // MARK: - HUD

    public var hudBackground = SKColor(red: 0.075, green: 0.098, blue: 0.075, alpha: 0.98)
    public var hudText = SKColor(red: 0.914, green: 0.894, blue: 0.831, alpha: 1.00)
    /// Secondary text: field labels, hints, the round counter's divisor.
    public var hudMutedText = SKColor(red: 0.482, green: 0.541, blue: 0.455, alpha: 1.00)
    /// The unit cards' panel.
    public var cardFill = SKColor(red: 0.106, green: 0.137, blue: 0.102, alpha: 1.00)
    public var cardStroke = SKColor(red: 0.173, green: 0.212, blue: 0.161, alpha: 1.00)
    /// Hairlines between panels and between commands.
    public var panelDivider = SKColor(red: 0.173, green: 0.212, blue: 0.161, alpha: 1.00)

    // MARK: - Commands

    public var buttonFill = SKColor(red: 0.137, green: 0.173, blue: 0.133, alpha: 1.00)
    public var buttonDisabledFill = SKColor(red: 0.086, green: 0.110, blue: 0.082, alpha: 1.00)
    public var buttonText = SKColor(red: 0.914, green: 0.894, blue: 0.831, alpha: 1.00)
    public var buttonDisabledText = SKColor(red: 0.353, green: 0.400, blue: 0.333, alpha: 1.00)
    public var buttonStroke = SKColor(red: 0.231, green: 0.282, blue: 0.216, alpha: 1.00)
    public var buttonDangerFill = SKColor(red: 0.294, green: 0.110, blue: 0.090, alpha: 1.00)
    public var buttonDangerStroke = SKColor(red: 0.737, green: 0.290, blue: 0.212, alpha: 1.00)
    public var buttonConfirmFill = SKColor(red: 0.157, green: 0.212, blue: 0.145, alpha: 1.00)
    public var buttonConfirmStroke = SKColor(red: 0.420, green: 0.549, blue: 0.333, alpha: 1.00)
    public var dimmingOverlay = SKColor(red: 0.02, green: 0.03, blue: 0.02, alpha: 0.80)

    /// Fraction of a tank's HP that counts as "low" and turns red.
    public var lowHPFraction: CGFloat = 0.35

    /// Everything has a default, so `BoardTheme()` is the standard look and a
    /// variant only names what it changes.
    public init() {}

    public static var standard: BoardTheme { BoardTheme() }

    public func hpBarColor(forFraction fraction: CGFloat) -> SKColor {
        fraction <= lowHPFraction ? hpBarLowFill : hpBarFill
    }

    /// The color that means "this side", on tanks and on their cards.
    public func sideColor(_ side: Side) -> SKColor {
        PlaceholderPalette.standard.color(for: side)
    }

    public func palette(for style: ButtonStyle) -> ButtonPalette {
        switch style {
        case .danger:
            return ButtonPalette(fill: buttonDangerFill, stroke: buttonDangerStroke, text: buttonText)
        case .confirm:
            return ButtonPalette(fill: buttonConfirmFill, stroke: buttonConfirmStroke, text: buttonText)
        case .neutral:
            return ButtonPalette(fill: buttonFill, stroke: buttonStroke, text: buttonText)
        }
    }

    public var disabledPalette: ButtonPalette {
        ButtonPalette(fill: buttonDisabledFill,
                      stroke: SKColor(white: 1.0, alpha: 0.06),
                      text: buttonDisabledText)
    }

    // MARK: - Type

    /// The end-screen headline.
    @MainActor public var titleStyle: TextStyle {
        TextStyle(size: 40, color: hudText, tracking: 3.0, uppercase: true)
    }

    /// The operation name, and a unit's name on its card.
    @MainActor public var bannerStyle: TextStyle {
        TextStyle(size: 20, color: hudText, tracking: 1.6, uppercase: true)
    }

    /// The tiny tracked caps above a value: OPERATION, TURN, SHELLS, DAMAGE.
    @MainActor public var fieldLabelStyle: TextStyle {
        TextStyle(size: 9, color: hudMutedText, tracking: 1.4, uppercase: true)
    }

    /// A value under a field label.
    @MainActor public var fieldValueStyle: TextStyle {
        TextStyle(fontCandidates: BoardFonts.readout, size: 12, color: hudText, uppercase: true)
    }

    /// The round counter's big amber number.
    @MainActor public var counterStyle: TextStyle {
        TextStyle(size: 22, color: frameAccent, tracking: 1.0)
    }

    /// Button captions.
    @MainActor public var buttonStyle: TextStyle {
        TextStyle(size: 17, color: buttonText, tracking: 1.6, uppercase: true)
    }

    /// Command-bar captions, which sit under an icon and so run smaller.
    @MainActor public var commandStyle: TextStyle {
        TextStyle(size: 10, color: buttonText, tracking: 1.2, uppercase: true)
    }

    /// Stats and the round counter: numerals first.
    @MainActor public var readoutStyle: TextStyle {
        TextStyle(fontCandidates: BoardFonts.readout, size: 15, color: hudMutedText)
    }

    /// The damage preview and the prompts that tell the player what to tap.
    @MainActor public var previewStyle: TextStyle {
        TextStyle(fontCandidates: BoardFonts.readout, size: 14, color: hudText)
    }
}
