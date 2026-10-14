import SpriteKit
import TankGameCore

/// The board: terrain, supply markers, tile highlights and tanks.
///
/// It renders whatever `GameState` it is handed and animates `GameEvent`s. It
/// holds no rules and makes no decisions; `BoardInteraction` does that.
@MainActor
public final class BoardNode: SKNode {

    public let layout: BoardLayout
    private let catalog: SpriteCatalog
    private let theme: BoardTheme

    private let terrainLayer = SKNode()
    private let highlightLayer = SKNode()
    private let tankLayer = SKNode()
    /// The yellow X on targetable enemies. Its own layer, above the tanks,
    /// because the X is drawn on top of the tank it marks.
    private let markerLayer = SKNode()
    private let effectLayer = SKNode()
    private var tankSprites: [TankID: TankSprite] = [:]

    /// Seconds per tile of driving, and the beat each shot takes. One tile always
    /// costs the same time, so the tank crawls at a constant speed regardless of
    /// the terrain it is crossing.
    public var driveDurationPerTile: TimeInterval = 0.10
    public var shotDuration: TimeInterval = 0.22

    /// Action key for any driving animation, preview or committed.
    static let driveKey = "drive"

    /// - Parameter art: the Tiled map the state's map was read from, whose
    ///   tile layers are drawn under the grid; nil for the per-tile terrain.
    public init(state: GameState, catalog: SpriteCatalog, theme: BoardTheme = .standard,
                art: TiledMap? = nil) {
        self.layout = BoardLayout(map: state.map, tileSize: catalog.tileSize)
        self.catalog = catalog
        self.theme = theme
        super.init()

        terrainLayer.zPosition = 0
        highlightLayer.zPosition = 2
        tankLayer.zPosition = 10
        markerLayer.zPosition = 15
        effectLayer.zPosition = 20
        [terrainLayer, highlightLayer, tankLayer, markerLayer, effectLayer].forEach(addChild)

        buildTerrain(map: state.map, art: art)
        buildTanks(state: state)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public var size: CGSize { layout.size }

    /// The tile under a point given in this node's coordinate space.
    public func tile(at point: CGPoint) -> Position? {
        layout.position(at: point)
    }

    // MARK: - Building

    /// A map's own art replaces the terrain tiles outright: it already shows
    /// what each tile is, so only a faint grid goes on top of it. Without it
    /// (no Tiled map, or its tileset images missing) every tile gets its own
    /// `terrainNode`, as before.
    private func buildTerrain(map: GameMap, art: TiledMap?) {
        let artNode = art.flatMap { catalog.mapArtNode(for: $0, boardSize: layout.size) }
        if let artNode {
            terrainLayer.addChild(artNode)
            terrainLayer.addChild(gridLines())
        }

        for y in 0..<map.height {
            for x in 0..<map.width {
                let tile = Position(x: x, y: y)
                guard let terrain = map.terrain(at: tile) else { continue }

                if artNode == nil {
                    let node = catalog.terrainNode(terrain)
                    node.position = layout.point(for: tile)
                    terrainLayer.addChild(node)
                }

                // Supply markers sit on top of their (open ground) tile.
                if let owner = map.supplyOwner(at: tile) {
                    let marker = catalog.supplyNode(owner)
                    marker.position = layout.point(for: tile)
                    marker.zPosition = 1
                    terrainLayer.addChild(marker)
                }
            }
        }
    }

    /// Every tile boundary inside the board as one path, so a 16 x 24 map costs
    /// one node rather than one per line.
    private func gridLines() -> SKShapeNode {
        let path = CGMutablePath()
        for x in 1..<layout.width {
            let px = CGFloat(x) * layout.tileSize
            path.move(to: CGPoint(x: px, y: 0))
            path.addLine(to: CGPoint(x: px, y: layout.size.height))
        }
        for y in 1..<layout.height {
            let py = CGFloat(y) * layout.tileSize
            path.move(to: CGPoint(x: 0, y: py))
            path.addLine(to: CGPoint(x: layout.size.width, y: py))
        }
        let lines = SKShapeNode(path: path)
        lines.strokeColor = theme.mapArtGridLine
        lines.lineWidth = 1
        lines.zPosition = 0.5
        return lines
    }

    private func buildTanks(state: GameState) {
        for tank in state.tanks {
            let sprite = TankSprite(tank: tank, stats: state.stats(of: tank),
                                    catalog: catalog, theme: theme)
            sprite.position = layout.point(for: tank.position)
            tankSprites[tank.id] = sprite
            tankLayer.addChild(sprite)
        }
    }

    // MARK: - Syncing with the model

    /// Snaps every sprite to the state. Called after animations and whenever the
    /// board might have drifted (a rejected action, a new match).
    ///
    /// A tank that is mid-drive keeps the position it has; the drive's own end
    /// puts it on the right tile.
    public func sync(with state: GameState) {
        for tank in state.tanks {
            guard let sprite = tankSprites[tank.id] else { continue }
            sprite.update(tank: tank, stats: state.stats(of: tank))
            sprite.setDimmed(tank.side != state.currentSide)
            sprite.setSpent(tank.side == state.currentSide && state.hasActed(tank.id))

            let isDriving = sprite.action(forKey: Self.driveKey) != nil
            if !isDriving {
                sprite.position = layout.point(for: tank.position)
            }
        }
    }

    public func setSelectedTank(_ tankID: TankID?) {
        for (id, sprite) in tankSprites {
            sprite.isSelected = (id == tankID)
        }
    }

    /// Rings the tank the HUD is describing, so the line of stats is never
    /// about a tank the player cannot pick out.
    public func setInspectedTank(_ tankID: TankID?) {
        for (id, sprite) in tankSprites {
            sprite.isInspected = (tankID != nil && id == tankID)
        }
    }

    /// The tile a tank's sprite is drawn on right now, which during a planned
    /// move is not the tile the rules have it on. For tests.
    func tileShowing(tankID: TankID) -> Position? {
        tankSprites[tankID].flatMap { tile(at: $0.position) }
    }

    // MARK: - Highlights

    /// Draws the move options, a yellow X on every enemy in range of Tile1, and
    /// the route to Tile1. Replaces whatever was shown before.
    public func showHighlights(moveTiles: [Position],
                               targetTiles: [Position],
                               path: [Position],
                               aimedTile: Position?) {
        highlightLayer.removeAllChildren()
        markerLayer.removeAllChildren()

        for tile in moveTiles {
            highlightLayer.addChild(tileOverlay(at: tile, color: theme.moveHighlight))
        }
        for tile in targetTiles {
            markerLayer.addChild(targetMark(at: tile))
        }
        if let aimedTile {
            highlightLayer.addChild(reticle(at: aimedTile))
        }
        if path.count > 1 {
            let line = CGMutablePath()
            line.move(to: layout.point(for: path[0]))
            for tile in path.dropFirst() {
                line.addLine(to: layout.point(for: tile))
            }
            let route = SKShapeNode(path: line)
            route.strokeColor = theme.pathHint
            route.lineWidth = 3
            route.lineCap = .round
            route.zPosition = 3
            highlightLayer.addChild(route)

            // A dot marks Tile1. It pulses because the tank has not gone there:
            // a second tap on it is what moves the tank.
            let stop = SKShapeNode(circleOfRadius: layout.tileSize * 0.12)
            stop.fillColor = theme.pathHint
            stop.lineWidth = 0
            stop.position = layout.point(for: path[path.count - 1])
            stop.zPosition = 3
            stop.run(.repeatForever(.sequence([
                .scale(to: 1.4, duration: 0.5),
                .scale(to: 1.0, duration: 0.5),
            ])))
            highlightLayer.addChild(stop)
        }
    }

    public func clearHighlights() {
        highlightLayer.removeAllChildren()
        markerLayer.removeAllChildren()
    }

    /// The yellow X drawn on top of an enemy that can be hit from Tile1. A dark
    /// stroke under the yellow one keeps it readable over any tank or terrain.
    private func targetMark(at tile: Position) -> SKNode {
        let half = layout.tileSize * 0.22
        let cross = CGMutablePath()
        cross.move(to: CGPoint(x: -half, y: -half))
        cross.addLine(to: CGPoint(x: half, y: half))
        cross.move(to: CGPoint(x: -half, y: half))
        cross.addLine(to: CGPoint(x: half, y: -half))

        let group = SKNode()
        group.position = layout.point(for: tile)
        group.name = Self.targetMarkName
        for (color, width) in [(theme.targetMarkOutline, layout.tileSize * 0.13),
                               (theme.targetMark, layout.tileSize * 0.07)] {
            let stroke = SKShapeNode(path: cross)
            stroke.strokeColor = color
            stroke.lineWidth = width
            stroke.lineCap = .round
            group.addChild(stroke)
        }
        return group
    }

    static let targetMarkName = "targetMark"

    /// Tiles currently carrying a yellow X. For tests.
    func targetMarkTiles() -> [Position] {
        markerLayer.children
            .filter { $0.name == Self.targetMarkName }
            .compactMap { tile(at: $0.position) }
    }

    /// The target marker: a ring with ticks, matching the command bar's attack
    /// icon so the same idea looks the same in both places.
    private func reticle(at tile: Position) -> SKNode {
        let group = SKNode()
        let radius = layout.tileSize * 0.44
        let colour = SKColor(red: 0.90, green: 0.30, blue: 0.24, alpha: 1)

        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = colour
        ring.lineWidth = 2
        ring.fillColor = .clear
        group.addChild(ring)

        let ticks = CGMutablePath()
        for (dx, dy) in [(0.0, 1.0), (0.0, -1.0), (1.0, 0.0), (-1.0, 0.0)] {
            ticks.move(to: CGPoint(x: radius * 0.55 * dx, y: radius * 0.55 * dy))
            ticks.addLine(to: CGPoint(x: radius * 1.3 * dx, y: radius * 1.3 * dy))
        }
        let marks = SKShapeNode(path: ticks)
        marks.strokeColor = colour
        marks.lineWidth = 2
        marks.lineCap = .round
        group.addChild(marks)

        group.position = layout.point(for: tile)
        group.zPosition = 3
        return group
    }

    private func tileOverlay(at tile: Position, color: SKColor) -> SKNode {
        let node = SKShapeNode(rectOf: CGSize(width: layout.tileSize - 2,
                                              height: layout.tileSize - 2),
                               cornerRadius: 3)
        node.fillColor = color
        node.strokeColor = .clear
        node.position = layout.point(for: tile)
        return node
    }

    // MARK: - Animating events

    /// Replays the events from one action, in order, then syncs and calls back.
    /// The caller should block input until `completion` runs.
    public func play(_ events: [GameEvent], state: GameState,
                     completion: @escaping () -> Void) {
        var remaining = events
        func next() {
            guard !remaining.isEmpty else {
                sync(with: state)
                completion()
                return
            }
            let event = remaining.removeFirst()
            animate(event, state: state, then: next)
        }
        next()
    }

    private func animate(_ event: GameEvent, state: GameState,
                         then next: @escaping () -> Void) {
        switch event {
        case .moved(let tankID, let path):
            drive(tankID: tankID, along: path, then: next)

        case .resupplied(let tankID):
            resupplyFlash(tankID: tankID, then: next)

        case .attacked(let attacker, let defender, _, let destroyed),
             .counterattacked(let attacker, let defender, _, let destroyed):
            fire(from: attacker, at: defender, destroyed: destroyed, state: state, then: next)

        case .passed, .turnBegan, .gameEnded:
            next()   // nothing to show on the board; the HUD reports these
        }
    }

    private func drive(tankID: TankID, along path: [Position],
                       then next: @escaping () -> Void) {
        guard let sprite = tankSprites[tankID], let last = path.last, path.count > 1 else {
            return next()
        }

        // Defensive: a tank already parked on the destination has nothing left
        // to drive, and re-running the route would send it round twice.
        let destination = layout.point(for: last)
        if hypot(sprite.position.x - destination.x, sprite.position.y - destination.y) < 0.5 {
            return next()
        }

        let steps = path.dropFirst().map { tile in
            SKAction.move(to: layout.point(for: tile), duration: driveDurationPerTile)
        }
        sprite.run(.sequence(steps + [.run(next)]), withKey: Self.driveKey)
    }

    private func resupplyFlash(tankID: TankID, then next: @escaping () -> Void) {
        guard let sprite = tankSprites[tankID] else { return next() }
        let pulse = SKShapeNode(circleOfRadius: layout.tileSize * 0.2)
        pulse.strokeColor = theme.hpBarFill
        pulse.lineWidth = 3
        pulse.fillColor = .clear
        pulse.position = sprite.position
        effectLayer.addChild(pulse)
        pulse.run(.sequence([
            .group([.scale(to: 2.2, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]), completion: next)
    }

    private func fire(from attackerID: TankID, at defenderID: TankID,
                      destroyed: Bool, state: GameState,
                      then next: @escaping () -> Void) {
        guard let attacker = tankSprites[attackerID],
              let defender = tankSprites[defenderID] else { return next() }

        let shell = projectileNode()
        shell.position = attacker.position
        effectLayer.addChild(shell)

        shell.run(.sequence([
            .move(to: defender.position, duration: shotDuration),
            .removeFromParent(),
        ])) { [weak self] in
            guard let self else { return next() }
            // The hit: shake, then blow up if this shot was lethal.
            defender.run(.sequence([
                .moveBy(x: 0, y: self.layout.tileSize * 0.08, duration: 0.05),
                .moveBy(x: 0, y: -self.layout.tileSize * 0.08, duration: 0.05),
            ]))
            defender.update(tank: state.tanks[defenderID], stats: state.stats(of: state.tanks[defenderID]))

            guard destroyed else {
                self.run(.wait(forDuration: 0.12), completion: next)
                return
            }
            self.explode(at: defender.position, then: next)
        }
    }

    private func projectileNode() -> SKNode {
        if let texture = catalog.effectTexture(.projectile) {
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: layout.tileSize * 0.2, height: layout.tileSize * 0.2)
            return sprite
        }
        let shell = SKShapeNode(circleOfRadius: max(2, layout.tileSize * 0.06))
        shell.fillColor = theme.hudText
        shell.strokeColor = .clear
        return shell
    }

    private func explode(at point: CGPoint, then next: @escaping () -> Void) {
        let blast: SKNode
        if let texture = catalog.effectTexture(.explosion) {
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: layout.tileSize, height: layout.tileSize)
            blast = sprite
        } else {
            let shape = SKShapeNode(circleOfRadius: layout.tileSize * 0.25)
            shape.fillColor = theme.attackHighlight
            shape.strokeColor = theme.hudText
            shape.lineWidth = 2
            blast = shape
        }
        blast.position = point
        effectLayer.addChild(blast)
        blast.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]), completion: next)
    }
}
