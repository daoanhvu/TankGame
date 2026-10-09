import SpriteKit
import TankGameCore

/// A tappable plate with a stencilled caption. Drawn in code, like every other
/// UI overlay.
///
/// The look is a bevelled metal switch: a drop shadow, a flat fill, a lit top
/// gloss, a coloured rim. `BoardTheme.ButtonStyle` decides the rim and fill, so
/// firing never looks like cancelling.
@MainActor
public final class ButtonNode: SKNode {

    /// How the control is drawn. `.plate` is a standalone bevelled button;
    /// `.command` is one cell of the segmented bar along the bottom of the
    /// screen, where the icon carries the meaning and the caption confirms it.
    public enum Appearance: Sendable { case plate, command }

    public let identifier: String
    public let style: BoardTheme.ButtonStyle
    public let appearance: Appearance
    public var onTap: (() -> Void)?

    private let shadow: SKShapeNode
    private let background: SKShapeNode
    private let gloss: SKShapeNode
    private let label: SKLabelNode
    private let icon: CommandIcon?
    private var iconNode: SKNode?
    private let theme: BoardTheme
    private let textStyle: TextStyle

    public init(identifier: String, title: String, size: CGSize, theme: BoardTheme,
                style: BoardTheme.ButtonStyle = .neutral,
                appearance: Appearance = .plate,
                icon: CommandIcon? = nil) {
        self.identifier = identifier
        self.style = style
        self.appearance = appearance
        self.icon = icon
        self.theme = theme

        let radius = appearance == .command ? 2 : min(6, size.height / 3)
        let palette = theme.palette(for: style)

        shadow = SKShapeNode(rectOf: size, cornerRadius: radius)
        shadow.fillColor = SKColor(white: 0, alpha: 0.45)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -2)

        background = SKShapeNode(rectOf: size, cornerRadius: radius)
        background.fillColor = palette.fill
        background.strokeColor = palette.stroke
        background.lineWidth = 1.5

        // A lighter band across the top half fakes a lit bevel; SpriteKit shape
        // nodes have no gradients, and two flat tones read the same at this size.
        gloss = SKShapeNode(rectOf: CGSize(width: size.width - 5, height: size.height * 0.42),
                            cornerRadius: radius * 0.6)
        gloss.fillColor = SKColor(white: 1, alpha: 0.07)
        gloss.strokeColor = .clear
        gloss.position = CGPoint(x: 0, y: size.height * 0.24)

        // Captions are short, so they can take wide tracking without crowding.
        // The size tracks the plate so a narrow four-button row still fits.
        textStyle = appearance == .command
            ? theme.commandStyle.colored(palette.text)
            : theme.buttonStyle.sized(min(17, size.height * 0.40)).colored(palette.text)
        label = textStyle.makeLabel(title)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        super.init()
        addChild(shadow)
        addChild(background)
        addChild(gloss)
        addChild(label)
        name = identifier

        if appearance == .command {
            // A cell in the bar: no bevel, no rim, the panel shows through.
            shadow.isHidden = true
            gloss.isHidden = true
            background.fillColor = .clear
            background.strokeColor = .clear
            let radius = min(11, size.height * 0.24)
            label.position = CGPoint(x: 0, y: -size.height * 0.30)
            iconRadiusBase = radius
            iconPosition = CGPoint(x: 0, y: size.height * 0.12)
            if let icon {
                let node = icon.node(radius: radius, color: palette.text)
                node.position = iconPosition
                iconNode = node
                addChild(node)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public var title: String {
        get { label.attributedText?.string ?? label.text ?? "" }
        set { textStyle.apply(to: label, text: newValue) }
    }

    public var isEnabled: Bool = true {
        didSet {
            let palette = isEnabled ? theme.palette(for: style) : theme.disabledPalette
            textStyle.colored(palette.text).apply(to: label, text: title)

            guard appearance == .plate else {
                // A command cell shows its state through the icon and caption;
                // giving it a fill would break the run of the bar.
                redrawIcon(color: palette.text)
                alpha = 1.0
                return
            }
            background.fillColor = palette.fill
            background.strokeColor = palette.stroke
            gloss.isHidden = !isEnabled
            shadow.isHidden = !isEnabled
            alpha = isEnabled ? 1.0 : 0.75
        }
    }

    /// Lifts the one command the player is most likely to want next, the way
    /// the middle cell is lifted in the design.
    public var isPrimary: Bool = false {
        didSet {
            guard appearance == .command, isPrimary != oldValue else { return }
            background.fillColor = isPrimary
                ? theme.buttonFill.withAlphaComponent(0.55) : .clear
        }
    }

    private func redrawIcon(color: SKColor) {
        guard let icon else { return }
        iconNode?.removeFromParent()
        let radius = min(11, iconRadiusBase)
        let node = icon.node(radius: radius, color: color)
        node.position = iconPosition
        iconNode = node
        addChild(node)
    }

    private var iconRadiusBase: CGFloat = 11
    private var iconPosition: CGPoint = .zero

    /// Whether this button would react to a tap at all.
    public var isTappable: Bool {
        guard isEnabled, !isHidden else { return false }
        // A hidden ancestor (e.g. the whole HUD) hides us too.
        var node: SKNode? = parent
        while let current = node {
            if current.isHidden { return false }
            node = current.parent
        }
        return true
    }

    /// The topmost tappable button under a scene point, optionally limited to
    /// the subtree below `root`. Walks up from the hit node because taps land on
    /// a button's background or label, not the button itself.
    public static func hitTest(_ point: CGPoint, in scene: SKScene,
                               within root: SKNode? = nil) -> ButtonNode? {
        for node in scene.nodes(at: point) {
            var candidate: SKNode? = node
            while let current = candidate {
                if let button = current as? ButtonNode, button.isTappable,
                   root == nil || button.isDescendant(of: root!) {
                    return button
                }
                candidate = current.parent
            }
        }
        return nil
    }

    private func isDescendant(of root: SKNode) -> Bool {
        var node: SKNode? = self
        while let current = node {
            if current === root { return true }
            node = current.parent
        }
        return false
    }

    /// Fires `onTap` with a short press animation: the plate sinks onto its own
    /// shadow and the rim flares, which is the whole feedback a tap gets.
    public func activate() {
        guard isEnabled else { return }
        run(.sequence([
            .scale(to: 0.95, duration: 0.05),
            .scale(to: 1.00, duration: 0.07),
        ]))
        shadow.run(.sequence([
            .fadeAlpha(to: 0.0, duration: 0.05),
            .fadeAlpha(to: 1.0, duration: 0.07),
        ]))
        if appearance == .plate {
            let rim = theme.palette(for: style).stroke
            background.strokeColor = theme.frameAccent
            run(.sequence([
                .wait(forDuration: 0.12),
                .run { [weak self] in
                    guard let self, self.isEnabled else { return }
                    self.background.strokeColor = rim
                },
            ]))
        }
        onTap?()
    }
}

extension Side {
    /// Player-facing name. Blue is the player's side, red the opponent's;
    /// in hot-seat both are human, so the color is what matters.
    public var displayName: String {
        switch self {
        case .player: return "Blue"
        case .ai: return "Red"
        }
    }
}

extension TankKind {
    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .medium: return "Medium"
        case .artillery: return "Artillery"
        }
    }
}
