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

/// The on-screen furniture, laid out as `docs/ScreenDesign.png` with one
/// departure from it: a single unit card, above the field.
///
///     OPERATION <name>                        ROUND 08 / 40
///     [ unit card — whichever tank is in focus              ]
///     SECTOR C-4                        BLUE 39 · RED 39
///     ( the board )
///     · awaiting command
///     [ attack | wait | cancel | pass ]
///
/// The design draws a card per side, but one card says the same thing and hands
/// the field 66pt back: the stripe down its edge is coloured from the tank, so
/// friendly and hostile never needed separate boxes.
///
/// It only reads a `BoardInteraction`; the scene wires the commands up.
/// Positioned in scene coordinates with the scene's origin at the bottom-left.
@MainActor
public final class HUDNode: SKNode {

    /// Only two commands are buttons. Moving, attacking and holding position
    /// are all taps on the board (see the Tap-flow in `docs/design.md`).
    public enum ButtonID {
        public static let cancel = "cancel"
        public static let pass = "pass"
    }

    public var onCancel: (() -> Void)?
    public var onPass: (() -> Void)?

    /// Shown under "OPERATION". The map's name, for want of a campaign.
    public var operationName: String = "Crossing" {
        didSet { theme.bannerStyle.apply(to: operationLabel, text: operationName) }
    }

    private let theme: BoardTheme
    private let catalog: SpriteCatalog
    private var sceneSize: CGSize
    private var insets: BoardInsets

    private let topPanel = SKNode()
    private let bottomPanel = SKNode()
    private let operationTag = SKLabelNode()
    private let operationLabel = SKLabelNode()
    private let turnTag = SKLabelNode()
    private let turnNumber = SKLabelNode()
    private let turnDivisor = SKLabelNode()
    private let sectorLabel = SKLabelNode()
    private let totalsLabel = SKLabelNode()
    private let statusDot = SKShapeNode(circleOfRadius: 3)
    private let statusLabel = SKLabelNode()
    /// Fed whatever `BoardInteraction.describedTankID` names: the player's own
    /// selection, an enemy they tapped to look at, or the tank they are aiming
    /// at — either side.
    private(set) var unitCard: UnitCardNode!
    private var buttons: [ButtonNode] = []

    // Heights of the stacked pieces. Chrome is generous on purpose: the board
    // is limited by the screen's WIDTH, so the room this takes was empty.
    private let topBarHeight: CGFloat = 52
    private let cardHeight: CGFloat = 66
    private let sectorHeight: CGFloat = 20
    private let statusHeight: CGFloat = 22
    private let commandHeight: CGFloat = 64
    private let margin: CGFloat = 10

    public init(sceneSize: CGSize, insets: BoardInsets = .zero,
                theme: BoardTheme = .standard, catalog: SpriteCatalog? = nil) {
        self.theme = theme
        self.catalog = catalog ?? SpriteCatalog()
        self.sceneSize = sceneSize
        self.insets = insets
        super.init()
        zPosition = 100
        addChild(topPanel)
        addChild(bottomPanel)
        rebuild()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Heights the board must stay clear of, chrome plus safe area.
    public var topInset: CGFloat {
        insets.top + topBarHeight + cardHeight + sectorHeight + margin
    }
    public var bottomInset: CGFloat {
        insets.bottom + commandHeight + statusHeight + margin
    }

    public func resize(to size: CGSize, insets: BoardInsets? = nil) {
        let newInsets = insets ?? self.insets
        guard size != sceneSize || newInsets != self.insets else { return }
        sceneSize = size
        self.insets = newInsets
        rebuild()
    }

    // MARK: - Layout

    private func rebuild() {
        topPanel.removeAllChildren()
        bottomPanel.removeAllChildren()
        buttons.removeAll()

        buildTopPanel()
        buildBottomPanel()
    }

    private func buildTopPanel() {
        // The panel runs to the screen edge so the notch area stays dark; only
        // the text respects the inset.
        let height = topInset
        let panel = SKSpriteNode(color: theme.hudBackground,
                                 size: CGSize(width: sceneSize.width, height: height))
        panel.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - height / 2)
        topPanel.addChild(panel)

        let top = sceneSize.height - insets.top

        theme.fieldLabelStyle.apply(to: operationTag, text: "operation")
        operationTag.horizontalAlignmentMode = .left
        operationTag.verticalAlignmentMode = .center
        operationTag.position = CGPoint(x: 16, y: top - 15)
        topPanel.addChild(operationTag)

        theme.bannerStyle.apply(to: operationLabel, text: operationName)
        operationLabel.horizontalAlignmentMode = .left
        operationLabel.verticalAlignmentMode = .center
        operationLabel.position = CGPoint(x: 16, y: top - 35)
        topPanel.addChild(operationLabel)

        theme.fieldLabelStyle.apply(to: turnTag, text: "round")
        turnTag.horizontalAlignmentMode = .right
        turnTag.verticalAlignmentMode = .center
        turnTag.position = CGPoint(x: sceneSize.width - 16, y: top - 15)
        topPanel.addChild(turnTag)

        turnDivisor.horizontalAlignmentMode = .right
        turnDivisor.verticalAlignmentMode = .center
        turnDivisor.position = CGPoint(x: sceneSize.width - 16, y: top - 36)
        topPanel.addChild(turnDivisor)

        turnNumber.horizontalAlignmentMode = .right
        turnNumber.verticalAlignmentMode = .center
        topPanel.addChild(turnNumber)

        // The one unit card: whatever is in focus, friendly or hostile.
        unitCard = UnitCardNode(
            size: CGSize(width: sceneSize.width - margin * 2, height: cardHeight),
            catalog: catalog, theme: theme)
        unitCard.position = CGPoint(x: margin, y: top - topBarHeight - cardHeight)
        topPanel.addChild(unitCard)

        // The strip between the chrome and the field.
        let stripY = sceneSize.height - topInset
        theme.fieldLabelStyle.apply(to: sectorLabel, text: "sector —")
        sectorLabel.horizontalAlignmentMode = .left
        sectorLabel.verticalAlignmentMode = .center
        sectorLabel.position = CGPoint(x: 16, y: stripY + sectorHeight / 2)
        topPanel.addChild(sectorLabel)

        totalsLabel.horizontalAlignmentMode = .right
        totalsLabel.verticalAlignmentMode = .center
        totalsLabel.position = CGPoint(x: sceneSize.width - 16, y: stripY + sectorHeight / 2)
        topPanel.addChild(totalsLabel)

        topPanel.addChild(hairline(atY: stripY, width: sceneSize.width))
    }

    private func buildBottomPanel() {
        let height = bottomInset
        let panel = SKSpriteNode(color: theme.hudBackground,
                                 size: CGSize(width: sceneSize.width, height: height))
        panel.position = CGPoint(x: sceneSize.width / 2, y: height / 2)
        bottomPanel.addChild(panel)
        bottomPanel.addChild(hairline(atY: height, width: sceneSize.width))

        // Status line: what the game is waiting for, or the damage preview.
        let statusY = insets.bottom + commandHeight + statusHeight / 2
        statusDot.fillColor = theme.frameAccent
        statusDot.strokeColor = .clear
        statusDot.position = CGPoint(x: sceneSize.width / 2 - 96, y: statusY)
        bottomPanel.addChild(statusDot)

        statusLabel.horizontalAlignmentMode = .center
        statusLabel.verticalAlignmentMode = .center
        statusLabel.numberOfLines = 2
        statusLabel.preferredMaxLayoutWidth = sceneSize.width - 32
        statusLabel.position = CGPoint(x: sceneSize.width / 2, y: statusY)
        bottomPanel.addChild(statusLabel)

        buildCommandBar()
    }

    /// One panel of equal cells divided by hairlines, as in the design, rather
    /// than separate buttons.
    private func buildCommandBar() {
        let specs: [(String, String, BoardTheme.ButtonStyle, CommandIcon)] = [
            (ButtonID.cancel, "Cancel", .neutral, .cancel),
            (ButtonID.pass, "End Turn", .neutral, .pass),
        ]
        let cellWidth = sceneSize.width / CGFloat(specs.count)
        let barBottom = insets.bottom

        bottomPanel.addChild(hairline(atY: barBottom + commandHeight, width: sceneSize.width,
                                      color: theme.panelDivider))

        for (index, (identifier, title, style, icon)) in specs.enumerated() {
            let button = ButtonNode(identifier: identifier, title: title,
                                    size: CGSize(width: cellWidth, height: commandHeight),
                                    theme: theme, style: style,
                                    appearance: .command, icon: icon)
            button.position = CGPoint(x: cellWidth * (CGFloat(index) + 0.5),
                                      y: barBottom + commandHeight / 2)
            button.onTap = { [weak self] in self?.handle(identifier) }
            buttons.append(button)
            bottomPanel.addChild(button)

            if index > 0 {
                let divider = SKSpriteNode(color: theme.panelDivider,
                                           size: CGSize(width: 1, height: commandHeight * 0.5))
                divider.position = CGPoint(x: cellWidth * CGFloat(index),
                                           y: barBottom + commandHeight / 2)
                bottomPanel.addChild(divider)
            }
        }
    }

    /// The thin amber rule that separates the chrome from the field.
    private func hairline(atY y: CGFloat, width: CGFloat, color: SKColor? = nil) -> SKNode {
        let line = SKSpriteNode(color: color ?? theme.frameAccent.withAlphaComponent(0.45),
                                size: CGSize(width: width, height: 1))
        line.position = CGPoint(x: width / 2, y: y)
        return line
    }

    private func handle(_ identifier: String) {
        switch identifier {
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

        // Turn counter: the number that moves is amber, the limit is not.
        theme.readoutStyle.sized(13).apply(to: turnDivisor, text: "/ \(state.config.maxRounds)")
        theme.counterStyle.apply(to: turnNumber, text: String(format: "%02d", state.round))
        turnNumber.position = CGPoint(x: turnDivisor.position.x - turnDivisor.frame.width - 5,
                                      y: turnDivisor.position.y)

        // One card, either side. `describedTankID` already ranks the
        // candidates — aimed target, then inspected tank, then the selection —
        // so the card needs no rule of its own about whose tank it may show.
        let focus = interaction.describedTankID.flatMap { state.tank($0) }
        unitCard.show(tank: focus, stats: focus.map(state.stats(of:)), in: state)

        // The strip: where the unit in focus is standing, and who is ahead.
        theme.fieldLabelStyle.apply(
            to: sectorLabel,
            text: focus.map { "sector \(Self.sector(of: $0.position))" } ?? "sector —")
        theme.fieldLabelStyle.apply(
            to: totalsLabel,
            text: "blue \(state.totalHP(of: .player)) hp  ·  red \(state.totalHP(of: .ai)) hp")

        theme.previewStyle.sized(12).apply(to: statusLabel, text: statusText(for: interaction))
        statusDot.position.x = statusLabel.frame.minX - 10

        setEnabled(ButtonID.cancel, interaction.plan != nil)
        setEnabled(ButtonID.pass, interaction.canPass)

        // With a tank selected the next move is on the board, so no button is
        // lifted; with nothing selected, End Turn is the only command there is.
        let primary = interaction.plan == nil ? ButtonID.pass : nil
        for button in buttons { button.isPrimary = (button.identifier == primary) }
    }

    /// A grid position as a map reference: column letter, row number.
    static func sector(of position: Position) -> String {
        let column = position.x < 26
            ? String(UnicodeScalar(UInt8(65 + position.x)))
            : "\(position.x + 1)"
        return "\(column)-\(position.y + 1)"
    }

    /// What the game is waiting for, or the damage the player is about to deal.
    private func statusText(for interaction: BoardInteraction) -> String {
        if case .finished = interaction.state.status { return "Match over" }
        // Nothing the player can do during Red's turn, so say what is happening
        // instead of inviting a tap that will be swallowed.
        if interaction.isAITurn {
            let left = interaction.pendingTankIDs.count
            return "\(interaction.currentSide.displayName) is moving…"
                + (left > 1 ? "   ·   \(left) units to go" : "")
        }

        guard let preview = interaction.attackPreview,
              let targetID = interaction.aimedTargetID,
              let target = interaction.state.tank(targetID) else {
            guard let plan = interaction.plan else {
                // A turn is one action per tank, so the count is the thing the
                // player most needs: it is what says the turn is not over.
                let left = interaction.pendingTankIDs.count
                let side = interaction.state.currentSide.displayName
                return left == 1
                    ? "\(side) to move — 1 unit left, or End Turn"
                    : "\(side) to move — \(left) units awaiting orders"
            }
            // Spell out what each tap would do from here: the flow has no
            // buttons for it, so this line is the only instruction.
            let hasTargets = !interaction.targetableTankIDs.isEmpty
            switch (plan.hasMoved, hasTargets) {
            case (true, true):  return "Tap an X to aim, or the marked tile again to move"
            case (true, false): return "Tap the marked tile again to move there"
            case (false, true): return "Tap an X to aim, a tile to move, or the tank to hold"
            case (false, false): return "Tap a tile to move, or the tank again to hold"
            }
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
        // The preview is the first of two taps; say what the second one does.
        return text + "   ·   tap again to fire"
    }

    private func setEnabled(_ identifier: String, _ enabled: Bool) {
        buttons.first { $0.identifier == identifier }?.isEnabled = enabled
    }

    /// Dims the controls while an animation plays. The scene is what actually
    /// swallows the input, so this is purely a hint to the player.
    public func setBusy(_ busy: Bool) {
        bottomPanel.alpha = busy ? 0.65 : 1.0
    }
}
