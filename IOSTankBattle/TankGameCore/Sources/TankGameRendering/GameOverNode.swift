import SpriteKit
import TankGameCore

/// The end-of-match screen: a dimming overlay, a framed plate carrying the
/// result, and a rematch button.
///
/// The plate borrows the board frame's bevel and brass rule so the ending reads
/// as part of the same machine.
@MainActor
public final class GameOverNode: SKNode {

    public static let rematchButtonID = "rematch"

    public var onRematch: (() -> Void)?

    private let theme: BoardTheme
    private var sceneSize: CGSize
    private var result: GameResult?
    private var lastState: GameState?

    public init(sceneSize: CGSize, theme: BoardTheme = .standard) {
        self.theme = theme
        self.sceneSize = sceneSize
        super.init()
        zPosition = 200
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public func resize(to size: CGSize) {
        guard size != sceneSize else { return }
        sceneSize = size
        if let result { show(result: result, in: lastState) }
    }

    /// Shows the result. `state` is optional and only used for the HP line at
    /// the round limit.
    public func show(result: GameResult, in state: GameState?) {
        self.result = result
        self.lastState = state
        removeAllChildren()
        isHidden = false

        let dim = SKSpriteNode(color: theme.dimmingOverlay, size: sceneSize)
        dim.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        addChild(dim)

        let panelSize = CGSize(width: min(340, sceneSize.width - 48),
                               height: min(260, sceneSize.height * 0.42))
        let center = CGPoint(x: sceneSize.width / 2, y: sceneSize.height * 0.52)
        addChild(panel(size: panelSize, at: center))

        let title = theme.titleStyle
            .sized(min(40, panelSize.width * 0.16))
            .makeLabel(headline(for: result))
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: center.x, y: center.y + panelSize.height * 0.26)
        addChild(title)

        // A short brass rule under the headline, the one piece of decoration the
        // panel needs to feel composed.
        let divider = SKSpriteNode(color: theme.frameAccent.withAlphaComponent(0.7),
                                   size: CGSize(width: panelSize.width * 0.42, height: 1.5))
        divider.position = CGPoint(x: center.x, y: center.y + panelSize.height * 0.14)
        addChild(divider)

        let detail = theme.previewStyle
            .sized(min(16, panelSize.width * 0.05))
            .colored(theme.hudMutedText)
            .makeLabel(subtitle(for: result, state: state))
        detail.horizontalAlignmentMode = .center
        detail.verticalAlignmentMode = .center
        detail.numberOfLines = 3
        detail.preferredMaxLayoutWidth = panelSize.width - 36
        detail.position = CGPoint(x: center.x, y: center.y - panelSize.height * 0.02)
        addChild(detail)

        let button = ButtonNode(identifier: Self.rematchButtonID, title: "New match",
                                size: CGSize(width: panelSize.width * 0.6, height: 46),
                                theme: theme, style: .confirm)
        button.position = CGPoint(x: center.x, y: center.y - panelSize.height * 0.3)
        button.onTap = { [weak self] in self?.onRematch?() }
        addChild(button)

        alpha = 0
        run(.fadeIn(withDuration: 0.3))
    }

    /// The same plate-and-brass construction as `BoardFrameNode`, at panel scale.
    private func panel(size: CGSize, at center: CGPoint) -> SKNode {
        let group = SKNode()

        let plate = SKShapeNode(rectOf: size, cornerRadius: 10)
        plate.fillColor = theme.framePlate
        plate.strokeColor = theme.framePlateEdge
        plate.lineWidth = 2
        plate.position = center
        group.addChild(plate)

        let bevel = SKShapeNode(rectOf: CGSize(width: size.width - 6, height: size.height - 6),
                                cornerRadius: 8)
        bevel.strokeColor = theme.frameHighlight
        bevel.lineWidth = 1.5
        bevel.fillColor = .clear
        bevel.position = center
        group.addChild(bevel)

        let rule = SKShapeNode(rectOf: CGSize(width: size.width - 16, height: size.height - 16),
                               cornerRadius: 5)
        rule.strokeColor = theme.frameAccent.withAlphaComponent(0.7)
        rule.lineWidth = 1.5
        rule.fillColor = .clear
        rule.position = center
        group.addChild(rule)

        for corner in [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1),
                       CGPoint(x: -1, y: 1), CGPoint(x: 1, y: 1)] {
            let bolt = SKShapeNode(circleOfRadius: 3)
            bolt.fillColor = theme.frameRivet
            bolt.strokeColor = theme.framePlateEdge
            bolt.lineWidth = 1
            bolt.position = CGPoint(x: center.x + corner.x * (size.width / 2 - 11),
                                    y: center.y + corner.y * (size.height / 2 - 11))
            group.addChild(bolt)
        }
        return group
    }

    public func hide() {
        result = nil
        lastState = nil
        isHidden = true
        removeAllChildren()
    }

    private func headline(for result: GameResult) -> String {
        switch result {
        case .draw: return "Draw"
        case .win(let side, _): return "\(side.displayName) wins"
        }
    }

    private func subtitle(for result: GameResult, state: GameState?) -> String {
        switch result {
        case .draw:
            guard let state else { return "Both sides finished level." }
            return "Equal HP at the round limit "
                + "(Blue \(state.totalHP(of: .player)), Red \(state.totalHP(of: .ai)))."
        case .win(_, .annihilation):
            return "Every enemy tank destroyed."
        case .win(let side, .moreHPAtRoundLimit):
            guard let state else { return "More HP left at the round limit." }
            return "Round limit reached — \(side.displayName) had more HP left "
                + "(Blue \(state.totalHP(of: .player)), Red \(state.totalHP(of: .ai)))."
        }
    }
}
