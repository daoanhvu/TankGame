import SpriteKit
import TankGameCore

/// Colors, type and sizes for the parts the game draws in code rather than as
/// art: the frame around the field, tile highlights, HP bars, ammo pips,
/// selection rings, the HUD and the buttons.
///
/// Art assets never cover these, so this stays valid when the placeholder
/// shapes are replaced by a real tile set. The look is a field manual: gunmetal
/// plate, brass rules, bone-white stencilled caps.
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

    // Board overlays
    public var moveHighlight: SKColor
    public var attackHighlight: SKColor
    public var selectionRing: SKColor
    public var pathHint: SKColor
    public var hpBarBackground: SKColor
    public var hpBarFill: SKColor
    public var hpBarLowFill: SKColor
    public var ammoPip: SKColor
    public var ammoPipEmpty: SKColor

    // Scene and frame
    /// Behind everything: the table the board sits on.
    public var sceneBackground: SKColor
    /// The steel plate the field is bolted into.
    public var framePlate: SKColor
    /// The plate's dark outer edge and the shadow under the board.
    public var framePlateEdge: SKColor
    /// The lit top edge of the bevel.
    public var frameHighlight: SKColor
    /// Brass: the inner rule, corner brackets, HUD rules.
    public var frameAccent: SKColor
    /// Corner bolts.
    public var frameRivet: SKColor

    // HUD
    public var hudBackground: SKColor
    public var hudText: SKColor
    /// Secondary text: stats, hints, the round counter.
    public var hudMutedText: SKColor
    public var buttonFill: SKColor
    public var buttonDisabledFill: SKColor
    public var buttonText: SKColor
    public var buttonDisabledText: SKColor
    public var buttonStroke: SKColor
    public var buttonDangerFill: SKColor
    public var buttonDangerStroke: SKColor
    public var buttonConfirmFill: SKColor
    public var buttonConfirmStroke: SKColor
    public var dimmingOverlay: SKColor

    /// Fraction of a tank's HP that counts as "low" and turns red.
    public var lowHPFraction: CGFloat

    public init(moveHighlight: SKColor, attackHighlight: SKColor, selectionRing: SKColor,
                pathHint: SKColor, hpBarBackground: SKColor, hpBarFill: SKColor,
                hpBarLowFill: SKColor, ammoPip: SKColor, ammoPipEmpty: SKColor,
                hudBackground: SKColor, hudText: SKColor, buttonFill: SKColor,
                buttonDisabledFill: SKColor, buttonText: SKColor, dimmingOverlay: SKColor,
                lowHPFraction: CGFloat,
                sceneBackground: SKColor = SKColor(red: 0.055, green: 0.070, blue: 0.082, alpha: 1),
                framePlate: SKColor = SKColor(red: 0.153, green: 0.176, blue: 0.196, alpha: 1),
                framePlateEdge: SKColor = SKColor(red: 0.047, green: 0.059, blue: 0.067, alpha: 1),
                frameHighlight: SKColor = SKColor(white: 1.0, alpha: 0.12),
                frameAccent: SKColor = SKColor(red: 0.776, green: 0.643, blue: 0.290, alpha: 1),
                frameRivet: SKColor = SKColor(red: 0.290, green: 0.325, blue: 0.353, alpha: 1),
                hudMutedText: SKColor = SKColor(red: 0.576, green: 0.631, blue: 0.663, alpha: 1),
                buttonDisabledText: SKColor = SKColor(red: 0.388, green: 0.427, blue: 0.451, alpha: 1),
                buttonStroke: SKColor = SKColor(red: 0.325, green: 0.372, blue: 0.408, alpha: 1),
                buttonDangerFill: SKColor = SKColor(red: 0.388, green: 0.145, blue: 0.118, alpha: 1),
                buttonDangerStroke: SKColor = SKColor(red: 0.737, green: 0.290, blue: 0.212, alpha: 1),
                buttonConfirmFill: SKColor = SKColor(red: 0.188, green: 0.255, blue: 0.180, alpha: 1),
                buttonConfirmStroke: SKColor = SKColor(red: 0.420, green: 0.549, blue: 0.333, alpha: 1)) {
        self.moveHighlight = moveHighlight
        self.attackHighlight = attackHighlight
        self.selectionRing = selectionRing
        self.pathHint = pathHint
        self.hpBarBackground = hpBarBackground
        self.hpBarFill = hpBarFill
        self.hpBarLowFill = hpBarLowFill
        self.ammoPip = ammoPip
        self.ammoPipEmpty = ammoPipEmpty
        self.hudBackground = hudBackground
        self.hudText = hudText
        self.buttonFill = buttonFill
        self.buttonDisabledFill = buttonDisabledFill
        self.buttonText = buttonText
        self.dimmingOverlay = dimmingOverlay
        self.lowHPFraction = lowHPFraction
        self.sceneBackground = sceneBackground
        self.framePlate = framePlate
        self.framePlateEdge = framePlateEdge
        self.frameHighlight = frameHighlight
        self.frameAccent = frameAccent
        self.frameRivet = frameRivet
        self.hudMutedText = hudMutedText
        self.buttonDisabledText = buttonDisabledText
        self.buttonStroke = buttonStroke
        self.buttonDangerFill = buttonDangerFill
        self.buttonDangerStroke = buttonDangerStroke
        self.buttonConfirmFill = buttonConfirmFill
        self.buttonConfirmStroke = buttonConfirmStroke
    }

    public static var standard: BoardTheme {
        BoardTheme(
            moveHighlight:       SKColor(red: 0.30, green: 0.70, blue: 1.00, alpha: 0.42),
            attackHighlight:     SKColor(red: 1.00, green: 0.30, blue: 0.25, alpha: 0.50),
            selectionRing:       SKColor(red: 1.00, green: 0.95, blue: 0.35, alpha: 1.00),
            pathHint:            SKColor(red: 0.98, green: 0.93, blue: 0.80, alpha: 0.85),
            hpBarBackground:     SKColor(white: 0.0, alpha: 0.55),
            hpBarFill:           SKColor(red: 0.47, green: 0.76, blue: 0.35, alpha: 1.00),
            hpBarLowFill:        SKColor(red: 0.90, green: 0.47, blue: 0.20, alpha: 1.00),
            ammoPip:             SKColor(red: 0.98, green: 0.93, blue: 0.80, alpha: 0.95),
            ammoPipEmpty:        SKColor(white: 1.0, alpha: 0.22),
            hudBackground:       SKColor(red: 0.086, green: 0.102, blue: 0.118, alpha: 0.97),
            hudText:             SKColor(red: 0.925, green: 0.906, blue: 0.855, alpha: 1.00),
            buttonFill:          SKColor(red: 0.169, green: 0.200, blue: 0.224, alpha: 1.00),
            buttonDisabledFill:  SKColor(red: 0.110, green: 0.133, blue: 0.149, alpha: 1.00),
            buttonText:          SKColor(red: 0.941, green: 0.925, blue: 0.878, alpha: 1.00),
            dimmingOverlay:      SKColor(red: 0.02, green: 0.03, blue: 0.04, alpha: 0.78),
            lowHPFraction: 0.35
        )
    }

    public func hpBarColor(forFraction fraction: CGFloat) -> SKColor {
        fraction <= lowHPFraction ? hpBarLowFill : hpBarFill
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
                      stroke: SKColor(white: 1.0, alpha: 0.10),
                      text: buttonDisabledText)
    }

    // MARK: - Type

    /// The end-screen headline.
    @MainActor public var titleStyle: TextStyle {
        TextStyle(size: 40, color: hudText, tracking: 3.0, uppercase: true)
    }

    /// Whose turn it is: the one label that should be readable at a glance.
    @MainActor public var bannerStyle: TextStyle {
        TextStyle(size: 22, color: hudText, tracking: 2.0, uppercase: true)
    }

    /// Button captions.
    @MainActor public var buttonStyle: TextStyle {
        TextStyle(size: 17, color: buttonText, tracking: 1.6, uppercase: true)
    }

    /// Stats and the round counter: numerals first.
    @MainActor public var readoutStyle: TextStyle {
        TextStyle(fontCandidates: BoardFonts.readout, size: 15, color: hudMutedText)
    }

    /// The damage preview and the prompts that tell the player what to tap.
    @MainActor public var previewStyle: TextStyle {
        TextStyle(fontCandidates: BoardFonts.readout, size: 15, color: hudText)
    }
}
