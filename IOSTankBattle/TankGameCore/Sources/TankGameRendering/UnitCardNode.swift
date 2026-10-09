import SpriteKit
import TankGameCore

/// One unit's dossier, as in `docs/ScreenDesign.png`: a side-coloured edge, a
/// portrait, the unit's name and range, an HP bar with the numbers, and the two
/// figures a player actually decides on — damage per shot and shells left.
///
/// There are two on screen, the side to move at the bottom and whatever it is
/// looking at on top, which is how a shared hull per side stops being
/// confusing (`docs/sprite_design.md` D2).
///
/// The design's LVL and AMMO TYPE fields have no counterpart in this game, so
/// those slots carry range and damage instead rather than inventing mechanics.
@MainActor
public final class UnitCardNode: SKNode {

    /// Which way the card's content reads; both look the same, but the side
    /// stripe and the empty-state wording differ.
    public enum Role { case friendly, hostile }

    public let role: Role
    public private(set) var size: CGSize

    private let theme: BoardTheme
    private let catalog: SpriteCatalog
    private let background: SKShapeNode
    private let sideStripe: SKSpriteNode
    private let portraitFrame: SKShapeNode
    private let portraitHolder = SKNode()
    private let nameLabel = SKLabelNode()
    private let rangeLabel = SKLabelNode()
    private let hpTag = SKLabelNode()
    private let hpTrack: SKSpriteNode
    private let hpFill: SKSpriteNode
    private let hpValue = SKLabelNode()
    private let damageTag = SKLabelNode()
    private let damageValue = SKLabelNode()
    private let shellsTag = SKLabelNode()
    private let shellsValue = SKLabelNode()
    private let emptyLabel = SKLabelNode()

    /// Which tank is currently drawn, so the portrait is only rebuilt when it
    /// actually changes — `update` runs on every tap.
    private var shownKind: TankKind?
    private var shownSide: Side?

    private let inset: CGFloat = 10
    private let gap: CGFloat = 10
    private var portraitSize: CGFloat { size.height - inset * 2 }
    private var textLeft: CGFloat { inset + portraitSize + gap }
    private var textRight: CGFloat { size.width - inset }
    /// The HP bar runs between its tag and the numbers, never under either.
    private var barStart: CGFloat { textLeft + 22 }
    private var barWidth: CGFloat { max(textRight - 48 - barStart, 10) }

    public init(size: CGSize, role: Role, catalog: SpriteCatalog, theme: BoardTheme) {
        self.size = size
        self.role = role
        self.theme = theme
        self.catalog = catalog

        background = SKShapeNode(rect: CGRect(origin: .zero, size: size), cornerRadius: 4)
        background.fillColor = theme.cardFill
        background.strokeColor = theme.cardStroke
        background.lineWidth = 1

        sideStripe = SKSpriteNode(color: .clear, size: CGSize(width: 3, height: size.height))
        sideStripe.anchorPoint = .zero

        portraitFrame = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.height - 20,
                                                 height: size.height - 20), cornerRadius: 3)
        portraitFrame.fillColor = theme.framePlateEdge
        portraitFrame.strokeColor = theme.cardStroke
        portraitFrame.lineWidth = 1

        hpTrack = SKSpriteNode(color: theme.hpBarBackground, size: CGSize(width: 10, height: 5))
        hpTrack.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: 5))
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)

        super.init()
        addChild(background)
        addChild(sideStripe)
        addChild(portraitFrame)
        addChild(portraitHolder)
        addChild(hpTrack)
        addChild(hpFill)
        [nameLabel, rangeLabel, hpTag, hpValue, damageTag, damageValue,
         shellsTag, shellsValue, emptyLabel].forEach(addChild)
        layout()
        showEmpty()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public func resize(to newSize: CGSize) {
        guard newSize != size else { return }
        size = newSize
        background.path = CGPath(roundedRect: CGRect(origin: .zero, size: size),
                                 cornerWidth: 4, cornerHeight: 4, transform: nil)
        sideStripe.size = CGSize(width: 3, height: size.height)
        layout()
    }

    // MARK: - Layout

    private func layout() {
        let portrait = portraitSize
        portraitFrame.path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: portrait, height: portrait),
                                    cornerWidth: 3, cornerHeight: 3, transform: nil)
        portraitFrame.position = CGPoint(x: inset, y: inset)
        portraitHolder.position = CGPoint(x: inset + portrait / 2, y: inset + portrait / 2)

        let right = textRight

        // Four lanes down the card: name, HP, field tags, field values.
        let nameY = size.height - 19
        let hpY = size.height - 36
        let tagY = size.height - 48
        let valueY = size.height - 58

        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: textLeft, y: nameY)

        rangeLabel.horizontalAlignmentMode = .right
        rangeLabel.verticalAlignmentMode = .center
        rangeLabel.position = CGPoint(x: right, y: nameY)

        // HP row: a tiny tag, the bar, then the numbers hard right.
        hpTag.horizontalAlignmentMode = .left
        hpTag.verticalAlignmentMode = .center
        hpTag.position = CGPoint(x: textLeft, y: hpY)

        hpTrack.position = CGPoint(x: barStart, y: hpY)
        hpTrack.size = CGSize(width: barWidth, height: 4)
        hpFill.position = hpTrack.position
        hpFill.size.height = 4

        hpValue.horizontalAlignmentMode = .right
        hpValue.verticalAlignmentMode = .center
        hpValue.position = CGPoint(x: right, y: hpY)
        damageTag.horizontalAlignmentMode = .left
        damageTag.verticalAlignmentMode = .center
        damageTag.position = CGPoint(x: textLeft, y: tagY)
        damageValue.horizontalAlignmentMode = .left
        damageValue.verticalAlignmentMode = .center
        damageValue.position = CGPoint(x: textLeft, y: valueY)

        shellsTag.horizontalAlignmentMode = .right
        shellsTag.verticalAlignmentMode = .center
        shellsTag.position = CGPoint(x: right, y: tagY)
        shellsValue.horizontalAlignmentMode = .right
        shellsValue.verticalAlignmentMode = .center
        shellsValue.position = CGPoint(x: right, y: valueY)

        emptyLabel.horizontalAlignmentMode = .left
        emptyLabel.verticalAlignmentMode = .center
        emptyLabel.position = CGPoint(x: inset + 6, y: size.height / 2)
    }

    // MARK: - Contents

    /// Fills the card in, or empties it when there is nothing to show. The card
    /// keeps its size either way so the board never jumps.
    public func show(tank: Tank?, stats: TankStats?, in state: GameState) {
        guard let tank, let stats else {
            showEmpty()
            return
        }

        emptyLabel.isHidden = true
        portraitFrame.isHidden = false
        for label in [nameLabel, rangeLabel, hpTag, hpValue,
                      damageTag, damageValue, shellsTag, shellsValue] {
            label.isHidden = false
        }
        hpTrack.isHidden = false
        hpFill.isHidden = false

        let side = tank.side
        sideStripe.color = theme.sideColor(side)
        background.strokeColor = theme.cardStroke

        if shownKind != tank.kind || shownSide != side {
            shownKind = tank.kind
            shownSide = side
            portraitHolder.removeAllChildren()
            portraitHolder.addChild(portrait(kind: tank.kind, side: side))
        }

        theme.bannerStyle.sized(16).apply(to: nameLabel, text: tank.kind.displayName)
        let range = stats.minRange == stats.maxRange
            ? "\(stats.maxRange)" : "\(stats.minRange)-\(stats.maxRange)"
        theme.fieldLabelStyle.apply(to: rangeLabel, text: "range \(range)  ·  move \(stats.movePoints)")

        theme.fieldLabelStyle.apply(to: hpTag, text: "hp")
        let fraction = stats.maxHP > 0
            ? max(0, min(1, CGFloat(tank.hp) / CGFloat(stats.maxHP))) : 0
        hpFill.size.width = barWidth * fraction
        // Tinted by side, as in the design: the exact HP is spelled out beside
        // it, so the bar's job is to say whose unit this is.
        hpFill.color = theme.sideColor(side)
        hpFill.isHidden = fraction == 0
        theme.fieldValueStyle.sized(13).colored(theme.hudText)
            .apply(to: hpValue, text: "\(tank.hp)/\(stats.maxHP)")

        theme.fieldLabelStyle.apply(to: damageTag, text: "damage")
        theme.fieldValueStyle.apply(to: damageValue, text: "\(stats.damage) per shot")
        theme.fieldLabelStyle.apply(to: shellsTag, text: "shells")
        theme.fieldValueStyle.sized(14)
            .colored(tank.hasAmmo ? theme.hudText : theme.hpBarLowFill)
            .apply(to: shellsValue, text: String(format: "%02d", tank.ammo))
    }

    private func showEmpty() {
        for label in [nameLabel, rangeLabel, hpTag, hpValue,
                      damageTag, damageValue, shellsTag, shellsValue] {
            label.isHidden = true
        }
        hpTrack.isHidden = true
        hpFill.isHidden = true
        portraitHolder.removeAllChildren()
        portraitFrame.isHidden = true
        shownKind = nil
        shownSide = nil
        sideStripe.color = theme.panelDivider
        background.strokeColor = theme.panelDivider

        emptyLabel.isHidden = false
        theme.fieldLabelStyle.colored(theme.hudMutedText)
            .apply(to: emptyLabel,
                   text: role == .friendly ? "no unit selected" : "no target")
    }

    /// The tank's own art, scaled to fit the portrait box. Goes through the
    /// catalog like every other visual, so it is whatever the board is showing.
    private func portrait(kind: TankKind, side: Side) -> SKNode {
        let holder = SKNode()
        let node = catalog.tankNode(kind: kind, side: side)
        // The catalog sizes tanks for a 64pt tile; the box is smaller, and an
        // AI hull arrives rotated to face down, which a portrait should not be.
        node.zRotation = 0
        for child in node.children { child.zRotation = 0 }
        node.setScale((portraitSize - 10) / (catalog.tileSize * 0.8))
        holder.addChild(node)
        return holder
    }
}
