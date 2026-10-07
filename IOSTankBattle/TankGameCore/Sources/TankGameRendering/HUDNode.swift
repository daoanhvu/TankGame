import SpriteKit
import TankGameCore

/// Space the HUD must keep clear of, so its text does not disappear behind a
/// notch, a Dynamic Island or a home indicator. The view controller supplies it.
public struct BoardInsets: Equatable, Sendable {
    public var top: CGFloat
    public var bottom: CGFloat

    public init(top: CGFloat = 0, bottom: CGFloat = 0) {
        self.top = top
        self.bottom = bottom
    }

    public static let zero = BoardInsets()
}

/// The on-screen furniture: whose turn it is, the round counter, details of the
/// selected tank, the damage preview, and the action buttons.
///
/// Two gunmetal panels, each closed off by a brass hairline, matching the frame
/// around the field. Positioned in scene coordinates with the scene's origin at
/// the bottom-left. It only reads a `BoardInteraction`; the scene wires the
/// buttons up.
@MainActor
public final class HUDNode: SKNode {

    public enum ButtonID {
        public static let attack = "attack"
        public static let wait = "wait"
        public static let cancel = "cancel"
        public static let pass = "pass"
    }

    public var onAttack: (() -> Void)?
    public var onWait: (() -> Void)?
    public var onCancel: (() -> Void)?
    public var onPass: (() -> Void)?

    private let theme: BoardTheme
    private var sceneSize: CGSize
    private var insets: BoardInsets

    private let topBar = SKNode()
    private let bottomBar = SKNode()
    private let turnLabel = SKLabelNode()
    private let roundLabel = SKLabelNode()
    private let selectionLabel = SKLabelNode()
    private let previewLabel = SKLabelNode()
    /// A colored tab in front of the turn banner: the fastest read of whose
    /// move it is.
    private let sideChip = SKShapeNode()
    private var buttons: [ButtonNode] = []

    public private(set) var barHeight: CGFloat = 0

    public init(sceneSize: CGSize, insets: BoardInsets = .zero, theme: BoardTheme = .standard) {
        self.theme = theme
        self.sceneSize = sceneSize
        self.insets = insets
        super.init()
        zPosition = 100
        addChild(topBar)
        addChild(bottomBar)
        rebuild()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Heights the board must stay clear of, bars plus safe area.
    public var topInset: CGFloat { barHeight + insets.top }
    public var bottomInset: CGFloat { barHeight + insets.bottom }

    public func resize(to size: CGSize, insets: BoardInsets? = nil) {
        let newInsets = insets ?? self.insets
        guard size != sceneSize || newInsets != self.insets else { return }
        sceneSize = size
        self.insets = newInsets
        rebuild()
    }

    // MARK: - Layout

    private func rebuild() {
        topBar.removeAllChildren()
        bottomBar.removeAllChildren()
        buttons.removeAll()

        barHeight = max(64, min(96, sceneSize.height * 0.11))

        // Top bar: turn, round, and what is selected. The background runs all
        // the way to the screen edge so the notch area stays dark; only the text
        // respects the inset.
        let topHeight = barHeight + insets.top
        let topEdge = sceneSize.height - insets.top
        let top = SKSpriteNode(color: theme.hudBackground,
                               size: CGSize(width: sceneSize.width, height: topHeight))
        top.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - topHeight / 2)
        topBar.addChild(top)
        topBar.addChild(rule(atY: sceneSize.height - topHeight))

        let banner = theme.bannerStyle.sized(min(22, barHeight * 0.26))
        turnLabel.horizontalAlignmentMode = .left
        turnLabel.verticalAlignmentMode = .center
        turnLabel.position = CGPoint(x: 32, y: topEdge - barHeight * 0.34)
        banner.apply(to: turnLabel, text: turnLabel.attributedText?.string ?? "")
        topBar.addChild(turnLabel)

        let chipSize = min(14, barHeight * 0.16)
        sideChip.path = CGPath(roundedRect: CGRect(x: -chipSize / 2, y: -chipSize / 2,
                                                   width: chipSize, height: chipSize),
                               cornerWidth: 2, cornerHeight: 2, transform: nil)
        sideChip.lineWidth = 1.5
        sideChip.strokeColor = theme.frameAccent.withAlphaComponent(0.6)
        sideChip.position = CGPoint(x: 18, y: topEdge - barHeight * 0.34)
        topBar.addChild(sideChip)

        roundLabel.horizontalAlignmentMode = .right
        roundLabel.verticalAlignmentMode = .center
        roundLabel.position = CGPoint(x: sceneSize.width - 16, y: topEdge - barHeight * 0.34)
        topBar.addChild(roundLabel)

        selectionLabel.horizontalAlignmentMode = .left
        selectionLabel.verticalAlignmentMode = .center
        selectionLabel.numberOfLines = 2
        selectionLabel.preferredMaxLayoutWidth = sceneSize.width - 36
        selectionLabel.position = CGPoint(x: 18, y: topEdge - barHeight * 0.72)
        topBar.addChild(selectionLabel)

        // Bottom bar: the damage preview above a row of buttons.
        let bottomHeight = barHeight + insets.bottom
        let bottom = SKSpriteNode(color: theme.hudBackground,
                                  size: CGSize(width: sceneSize.width, height: bottomHeight))
        bottom.position = CGPoint(x: sceneSize.width / 2, y: bottomHeight / 2)
        bottomBar.addChild(bottom)
        bottomBar.addChild(rule(atY: bottomHeight))

        previewLabel.horizontalAlignmentMode = .center
        previewLabel.verticalAlignmentMode = .center
        previewLabel.numberOfLines = 2
        previewLabel.preferredMaxLayoutWidth = sceneSize.width - 24
        previewLabel.position = CGPoint(x: sceneSize.width / 2, y: insets.bottom + barHeight * 0.76)
        bottomBar.addChild(previewLabel)

        let specs: [(String, String, BoardTheme.ButtonStyle)] = [
            (ButtonID.attack, "Attack", .danger),
            (ButtonID.wait, "Wait", .confirm),
            (ButtonID.cancel, "Cancel", .neutral),
            (ButtonID.pass, "Pass", .neutral),
        ]
        let margin: CGFloat = 12
        let gap: CGFloat = 8
        let buttonWidth = (sceneSize.width - margin * 2 - gap * CGFloat(specs.count - 1))
            / CGFloat(specs.count)
        let buttonHeight = min(42, barHeight * 0.48)

        for (index, (identifier, title, style)) in specs.enumerated() {
            let button = ButtonNode(identifier: identifier, title: title,
                                    size: CGSize(width: buttonWidth, height: buttonHeight),
                                    theme: theme, style: style)
            button.position = CGPoint(
                x: margin + buttonWidth / 2 + (buttonWidth + gap) * CGFloat(index),
                y: insets.bottom + barHeight * 0.3)
            button.onTap = { [weak self] in self?.handle(identifier) }
            buttons.append(button)
            bottomBar.addChild(button)
        }
    }

    /// The brass hairline that closes off a panel against the field, with a
    /// darker line under it so the edge has some depth.
    private func rule(atY y: CGFloat) -> SKNode {
        let group = SKNode()
        let brass = SKSpriteNode(color: theme.frameAccent.withAlphaComponent(0.65),
                                 size: CGSize(width: sceneSize.width, height: 1.5))
        brass.position = CGPoint(x: sceneSize.width / 2, y: y)
        group.addChild(brass)

        let shade = SKSpriteNode(color: SKColor(white: 0, alpha: 0.35),
                                 size: CGSize(width: sceneSize.width, height: 2))
        shade.position = CGPoint(x: sceneSize.width / 2, y: y - 1.5)
        group.addChild(shade)
        return group
    }

    private func handle(_ identifier: String) {
        switch identifier {
        case ButtonID.attack: onAttack?()
        case ButtonID.wait: onWait?()
        case ButtonID.cancel: onCancel?()
        case ButtonID.pass: onPass?()
        default: break
        }
    }

    // MARK: - Hit testing

    /// The button at a scene point, if any. Lets the scene decide between a HUD
    /// tap and a board tap.
    public func button(atScenePoint point: CGPoint) -> ButtonNode? {
        guard let scene else { return nil }
        return ButtonNode.hitTest(point, in: scene, within: self)
    }

    // MARK: - Contents

    public func update(with interaction: BoardInteraction) {
        let state = interaction.state
        let banner = theme.bannerStyle.sized(min(22, barHeight * 0.26))

        if case .finished = state.status {
            banner.apply(to: turnLabel, text: "Match over")
            sideChip.fillColor = theme.hudMutedText
        } else {
            banner.apply(to: turnLabel, text: "\(state.currentSide.displayName)'s turn")
            sideChip.fillColor = sideColor(state.currentSide)
        }
        theme.readoutStyle.sized(min(15, barHeight * 0.18))
            .apply(to: roundLabel, text: "Round \(state.round) / \(state.config.maxRounds)")

        theme.readoutStyle.sized(14).apply(to: selectionLabel, text: tankLine(for: interaction))

        theme.previewStyle.sized(min(15, barHeight * 0.18))
            .apply(to: previewLabel, text: previewText(for: interaction))

        setEnabled(ButtonID.attack, interaction.canAttack)
        setEnabled(ButtonID.wait, interaction.canWait)
        setEnabled(ButtonID.cancel, interaction.plan != nil)
        setEnabled(ButtonID.pass, interaction.canPass)
    }

    /// The side's placeholder color, so the chip agrees with the tanks on the
    /// board even if the palette is retuned.
    private func sideColor(_ side: Side) -> SKColor {
        PlaceholderPalette.standard.color(for: side)
    }

    /// What the player needs to know about one tank.
    ///
    /// Both sides wear one hull per side, so the board shows WHOSE a tank is
    /// and this line shows WHAT it is (`docs/sprite_design.md` D2). It
    /// describes whatever the player is aiming at, has selected, or last tapped
    /// to look at; with none of those it falls back to the HP totals, which is
    /// the only thing worth saying when nothing is picked.
    private func tankLine(for interaction: BoardInteraction) -> String {
        let state = interaction.state
        guard let tankID = interaction.describedTankID, let tank = state.tank(tankID) else {
            return "Blue \(state.totalHP(of: .player)) HP   ·   Red \(state.totalHP(of: .ai)) HP"
        }

        let stats = state.stats(of: tank)
        // Naming the side keeps an inspected enemy from reading as a selection.
        let name = tank.side == state.currentSide
            ? tank.kind.displayName
            : "\(tank.side.displayName) \(tank.kind.displayName)"
        let range = stats.minRange == stats.maxRange
            ? "\(stats.maxRange)"
            : "\(stats.minRange)-\(stats.maxRange)"

        var line = "\(name)   ·   HP \(tank.hp)/\(stats.maxHP)"
            + "   ·   Ammo \(tank.ammo)/\(stats.maxAmmo)"
            + "   ·   Range \(range)"
        if tankID == interaction.selectedTankID, let plan = interaction.plan, plan.hasMoved,
           let cost = plan.reachable[plan.destination] {
            line += "   ·   Move \(cost)/\(stats.movePoints)"
        }
        return line
    }

    /// The damage preview, counterattack included, which is the number the
    /// player actually decides on.
    private func previewText(for interaction: BoardInteraction) -> String {
        guard let preview = interaction.attackPreview,
              let targetID = interaction.aimedTargetID,
              let target = interaction.state.tank(targetID) else {
            guard let plan = interaction.plan else { return "Tap one of your tanks" }
            // Once the tank has rolled out, the next tap on that tile is the one
            // that spends the turn, so say so.
            return plan.hasMoved
                ? "Tap that tile again to confirm the move, or an enemy to attack"
                : "Tap a tile to move, or an enemy in range"
        }

        var text = "Deal \(preview.damage) to \(target.kind.displayName)"
        text += preview.targetDestroyed
            ? " — destroyed!"
            : " (\(target.hp) → \(target.hp - preview.damage) HP)"
        if preview.hasCounterattack {
            text += "   ·   take \(preview.counterDamage) back"
            if preview.attackerDestroyed { text += " — you would be destroyed!" }
        } else {
            text += "   ·   no counterattack"
        }
        return text
    }

    private func setEnabled(_ identifier: String, _ enabled: Bool) {
        buttons.first { $0.identifier == identifier }?.isEnabled = enabled
    }

    /// Dims the controls while an animation plays. The scene is what actually
    /// swallows the input, so this is purely a hint to the player.
    public func setBusy(_ busy: Bool) {
        bottomBar.alpha = busy ? 0.65 : 1.0
    }
}
