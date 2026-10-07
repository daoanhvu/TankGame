import SpriteKit
import TankGameCore

/// One tank on the board: the hull from `SpriteCatalog`, plus the overlays that
/// are always drawn in code (HP bar, ammo pips, selection ring).
///
/// Centered on (0, 0); the board positions it on the grid.
@MainActor
public final class TankSprite: SKNode {

    public let tankID: TankID

    private let tileSize: CGFloat
    private let theme: BoardTheme
    private let hull: SKNode
    private let hpBarFill: SKSpriteNode
    private let hpBarWidth: CGFloat
    private let ammoPips: [SKShapeNode]
    private let selectionRing: SKShapeNode
    private let inspectionRing: SKShapeNode

    public init(tank: Tank, stats: TankStats, catalog: SpriteCatalog, theme: BoardTheme) {
        self.tankID = tank.id
        self.tileSize = catalog.tileSize
        self.theme = theme

        // Every visual goes through the catalog, so swapping in real art needs
        // no changes here.
        self.hull = catalog.tankNode(for: tank)

        let barWidth = catalog.tileSize * 0.78
        let barHeight = max(3, catalog.tileSize * 0.075)
        self.hpBarWidth = barWidth

        let barBackground = SKSpriteNode(color: theme.hpBarBackground,
                                         size: CGSize(width: barWidth, height: barHeight))
        barBackground.position = CGPoint(x: 0, y: catalog.tileSize * 0.44)

        self.hpBarFill = SKSpriteNode(color: theme.hpBarFill,
                                      size: CGSize(width: barWidth, height: barHeight))
        hpBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)   // so it shrinks from the right
        hpBarFill.position = CGPoint(x: -barWidth / 2, y: barBackground.position.y)

        // One pip per shell the tank can carry, filled while the shell is there.
        let pipRadius = max(1.5, min(catalog.tileSize * 0.045,
                                     barWidth / CGFloat(max(stats.maxAmmo, 1)) * 0.4))
        let spacing = barWidth / CGFloat(max(stats.maxAmmo, 1))
        self.ammoPips = (0..<stats.maxAmmo).map { index in
            let pip = SKShapeNode(circleOfRadius: pipRadius)
            pip.lineWidth = 0
            pip.position = CGPoint(
                x: -barWidth / 2 + spacing * (CGFloat(index) + 0.5),
                y: -catalog.tileSize * 0.44)
            return pip
        }

        self.selectionRing = SKShapeNode(circleOfRadius: catalog.tileSize * 0.48)
        selectionRing.strokeColor = theme.selectionRing
        selectionRing.lineWidth = 3
        selectionRing.fillColor = .clear
        selectionRing.isHidden = true
        selectionRing.zPosition = -1

        // Marks the tank the HUD is describing. Quieter than the selection ring
        // and never pulsing, because looking at a tank is not picking it.
        // Thick enough to survive the board being scaled to ~0.47 to fit a
        // phone, which turns a hairline into nothing.
        self.inspectionRing = SKShapeNode(circleOfRadius: catalog.tileSize * 0.46)
        inspectionRing.strokeColor = theme.hudText
        inspectionRing.lineWidth = 3
        inspectionRing.fillColor = .clear
        inspectionRing.isHidden = true
        inspectionRing.zPosition = -1

        super.init()

        addChild(selectionRing)
        addChild(inspectionRing)
        addChild(hull)
        addChild(barBackground)
        addChild(hpBarFill)
        ammoPips.forEach(addChild)

        update(tank: tank, stats: stats)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - State

    /// Mirrors the tank's current HP and ammo into the overlays.
    public func update(tank: Tank, stats: TankStats) {
        let fraction = stats.maxHP > 0
            ? max(0, min(1, CGFloat(tank.hp) / CGFloat(stats.maxHP)))
            : 0
        hpBarFill.size.width = hpBarWidth * fraction
        hpBarFill.color = theme.hpBarColor(forFraction: fraction)
        hpBarFill.isHidden = fraction == 0

        for (index, pip) in ammoPips.enumerated() {
            pip.fillColor = index < tank.ammo ? theme.ammoPip : theme.ammoPipEmpty
        }

        // A destroyed tank stays in the model for stable IDs, but must not be
        // visible on the board.
        isHidden = !tank.isAlive
    }

    public var isSelected: Bool {
        get { !selectionRing.isHidden }
        set {
            selectionRing.isHidden = !newValue
            selectionRing.removeAction(forKey: "pulse")
            guard newValue else { return }
            selectionRing.run(.repeatForever(.sequence([
                .scale(to: 1.08, duration: 0.45),
                .scale(to: 1.00, duration: 0.45),
            ])), withKey: "pulse")
        }
    }

    /// Whether this tank is the one the HUD is describing.
    public var isInspected: Bool {
        get { !inspectionRing.isHidden }
        set { inspectionRing.isHidden = !newValue }
    }

    /// Dims tanks that cannot act, so the side to move stands out.
    ///
    /// Gentle on purpose: the placeholder shapes survived 0.55, but the atlas
    /// art is painted and detailed, and that much transparency blends it into
    /// the terrain instead of reading as "not your turn".
    public func setDimmed(_ dimmed: Bool) {
        alpha = dimmed ? 0.8 : 1.0
    }
}
