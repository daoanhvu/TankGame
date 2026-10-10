import SpriteKit
import TankGameCore
import TankGameAI

/// The playable board: the player commands Blue, a `TankAI` commands Red.
/// Pass `opponent: nil` for the milestone-2 hot seat, where both sides take
/// taps from the same device.
///
/// It is a thin shell. `BoardInteraction` holds the game and the tap flow,
/// `BoardNode` draws and animates, `HUDNode` reports and offers the buttons.
/// The scene's own job is routing input, blocking it while animating, and
/// giving the opponent a beat to "think" so its turn reads as a move rather
/// than a jump cut.
@MainActor
public final class BattleScene: SKScene {

    private let catalog: SpriteCatalog
    private let theme: BoardTheme
    private let newGame: () throws -> GameState

    /// The brain playing Red, or nil for hot seat. Swap it for a difficulty
    /// setting; the match keeps whatever state it is in.
    public var opponent: TankAI? {
        didSet {
            interaction.aiSide = opponent == nil ? nil : .ai
            guard board != nil else { return }
            refresh()
            advanceAIIfNeeded()
        }
    }

    /// How long Red appears to think before each of its moves plays. Short
    /// enough not to feel laggy, long enough to follow what moved.
    ///
    /// Per TANK, not per turn: Red commands all five in a turn, so this is
    /// spent up to five times in a row and is shorter than it would be for a
    /// single move.
    public var opponentDelay: TimeInterval = 0.3

    private var interaction: BoardInteraction
    private var board: BoardNode!
    private var boardFrame: BoardFrameNode!
    private var hud: HUDNode!
    private var gameOver: GameOverNode!
    private let boardContainer = SKNode()
    private let fieldBackground = SKSpriteNode()

    /// True while events are animating, when taps are ignored.
    private var isAnimating = false

    /// True from the moment Red's turn is scheduled until its action has been
    /// applied. Input stays locked for the whole of it, including the delay.
    private var isOpponentThinking = false

    /// True while a tank is rolling to a planned tile. A turn-based game should
    /// not let the player change their mind halfway through a move, so input is
    /// locked until it arrives.
    private var isDriving = false

    /// Whether the board is busy and should swallow input.
    private var isBusy: Bool { isAnimating || isDriving || isOpponentThinking }

    /// The tank currently standing on a planned tile rather than its real one,
    /// and the route it took to get there (starting at its real tile).
    ///
    /// The rules cannot move it yet — a turn is one atomic action and the player
    /// may still pick a target or cancel — so the sprite is driven ahead of the
    /// model and this is the bookkeeping that keeps the two reconcilable.
    private var previewTankID: TankID?
    private var previewRoute: [Position] = []

    /// Shown under "OPERATION" in the HUD. The map has no name of its own yet,
    /// so the scene carries one.
    public var operationName: String = "Crossing" {
        didSet { hud?.operationName = operationName }
    }

    /// Space to keep clear of the notch and the home indicator. The hosting
    /// view controller sets this once it knows its safe area.
    public var safeAreaInsets: BoardInsets = .zero {
        didSet {
            guard hud != nil, safeAreaInsets != oldValue else { return }
            hud.resize(to: size, insets: safeAreaInsets)
            layoutBoard()
        }
    }

    /// - Parameter newGame: builds a fresh state for the first match and every
    ///   rematch, so the scene never has to know how a match is set up.
    public init(size: CGSize,
                tileSize: CGFloat = 64,
                theme: BoardTheme = .standard,
                catalog: SpriteCatalog? = nil,
                opponent: TankAI? = GreedyAI(),
                newGame: @escaping () throws -> GameState) throws {
        self.catalog = catalog ?? SpriteCatalog(tileSize: tileSize)
        self.theme = theme
        self.newGame = newGame
        self.opponent = opponent
        self.interaction = BoardInteraction(state: try newGame(),
                                            aiSide: opponent == nil ? nil : .ai)
        super.init(size: size)

        scaleMode = .resizeFill
        anchorPoint = .zero       // scene origin at the bottom-left
        backgroundColor = theme.sceneBackground
    }

    /// Convenience for the standard phase-1 match on a built-in map.
    public convenience init(size: CGSize,
                            map ascii: String = Maps.crossing,
                            config: GameConfig = .phase1Default,
                            tileSize: CGFloat = 64,
                            theme: BoardTheme = .standard,
                            opponent: TankAI? = GreedyAI()) throws {
        try self.init(size: size, tileSize: tileSize, theme: theme, opponent: opponent) {
            try GameState.newGame(config: config, map: try GameMap(ascii: ascii))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Scene lifecycle

    public override func didMove(to view: SKView) {
        super.didMove(to: view)
        guard board == nil else { return }

        fieldBackground.color = theme.fieldBackground
        fieldBackground.anchorPoint = .zero
        fieldBackground.zPosition = -50
        addChild(fieldBackground)

        addChild(boardContainer)
        board = BoardNode(state: interaction.state, catalog: catalog, theme: theme)
        boardContainer.addChild(board)

        // The border shares the board's coordinate space, so it scales with the
        // field and never drifts off its edge.
        boardFrame = BoardFrameNode(boardSize: board.size, tileSize: catalog.tileSize, theme: theme)
        boardContainer.addChild(boardFrame)

        hud = HUDNode(sceneSize: size, insets: safeAreaInsets, theme: theme, catalog: catalog)
        hud.operationName = operationName
        addChild(hud)
        hud.onAttack = { [weak self] in self?.commit { $0.attack() } }
        hud.onWait = { [weak self] in self?.commit { $0.wait() } }
        hud.onPass = { [weak self] in self?.commit { $0.pass() } }
        hud.onCancel = { [weak self] in
            guard let self, !self.isAnimating else { return }
            self.interaction.cancel()
            self.refresh()
        }

        gameOver = GameOverNode(sceneSize: size, theme: theme)
        gameOver.onRematch = { [weak self] in self?.startNewMatch() }
        addChild(gameOver)

        layoutBoard()
        refresh()
        // Covers a config whose `firstSide` is the AI: the player should not
        // have to tap something to make the opponent open the match.
        advanceAIIfNeeded()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard board != nil else { return }
        hud.resize(to: size, insets: safeAreaInsets)
        gameOver.resize(to: size)
        layoutBoard()
    }

    /// Centers the board between the two HUD bars, scaled down if it does not
    /// fit the screen. The frame reaches outside the grid, so it has to be part
    /// of what gets fitted or the border would be cropped by the screen edge.
    private func layoutBoard() {
        let available = CGSize(width: size.width,
                               height: max(size.height - hud.topInset - hud.bottomInset, 1))
        let scale = board.layout.scaleToFit(available, padding: 6, outset: boardFrame.inset)

        fieldBackground.position = CGPoint(x: 0, y: hud.bottomInset)
        fieldBackground.size = CGSize(width: size.width, height: available.height)

        boardContainer.setScale(scale)
        boardContainer.position = CGPoint(
            x: (size.width - board.size.width * scale) / 2,
            y: hud.bottomInset + (available.height - board.size.height * scale) / 2)
    }

    // MARK: - Input

    /// A tap anywhere: the HUD gets first refusal, then the board.
    private func handleTap(atScenePoint point: CGPoint) {
        if let button = hud.button(atScenePoint: point) {
            if !isBusy { button.activate() }
            return
        }
        // The rematch button lives on the game-over overlay, which also blocks
        // the board underneath it.
        if !gameOver.isHidden {
            ButtonNode.hitTest(point, in: self, within: gameOver)?.activate()
            return
        }

        guard !isBusy, !interaction.isOver else { return }
        let boardPoint = board.convert(point, from: self)
        guard let tile = board.tile(at: boardPoint) else { return }
        tapBoard(tile)
    }

    /// One way in for a tap on a tile, so the scripted taps used by tests and
    /// previews cannot drift from what a finger does.
    private func tapBoard(_ tile: Position) {
        guard !isBusy, !interaction.isOver else { return }

        // Confirming a move returns the events for it; every other tap just
        // changes what is selected. Dropping these would advance the game
        // without ever animating it.
        let before = interaction.state
        let events = interaction.tapTile(tile)
        if interaction.state == before {
            refresh()
        } else {
            present(events)
        }
    }

    /// Runs one of the HUD's committing actions and animates what came out of it.
    ///
    /// An empty event list is NOT the same as "nothing happened": a tank told
    /// to hold its position produces no events at all, since there is no
    /// `.moved` to animate and `.turnBegan` only fires when the side actually
    /// changes. That action still spends the tank's go and may well end the
    /// turn, so what distinguishes it from an action the rules declined is
    /// whether the state moved, not whether there is anything to draw.
    private func commit(_ action: (inout BoardInteraction) -> [GameEvent]) {
        guard !isBusy, !interaction.isOver else { return }
        let before = interaction.state
        let events = action(&interaction)
        guard interaction.state != before else {
            refresh()               // declined (Attack with nothing aimed at)
            return
        }
        present(events)
    }

    /// Animates a committed action, from whichever path produced it: a HUD
    /// button, the confirmation tap on the destination tile, or Red's brain.
    /// Safe with an empty list, which just redraws and hands on.
    private func present(_ events: [GameEvent]) {
        isAnimating = true
        hud.setBusy(true)
        board.clearHighlights()
        board.setSelectedTank(nil)

        // If the committed action really moved the previewed tank, it is already
        // standing on the destination and the `.moved` event has nothing left to
        // animate. Otherwise (Pass, or a Wait that stayed put) the plan came to
        // nothing, so drive it home.
        if previewTankID.map({ events.moves(tankID: $0) }) == true {
            settlePreviewedTank()
        } else {
            recallPreviewedTank()
        }
        board.play(events, state: interaction.state) { [weak self] in
            guard let self else { return }
            self.isAnimating = false
            self.hud.setBusy(false)
            self.refresh()
            // Red's turn follows the player's, and the player's follows Red's
            // reply: one place to hand over, whichever side just acted.
            self.advanceAIIfNeeded()
        }
    }

    // MARK: - Red's turn

    /// Plays one of Red's moves if it is owed one, after a beat.
    ///
    /// Red's turn is several actions — one per tank — and this runs one of
    /// them. The completion of the animation calls it again, so the turn plays
    /// out tank by tank until the board comes back to Blue.
    ///
    /// Safe to call after anything: it is a no-op on a human turn, once the
    /// match is over, or while the board is already busy — the thing that was
    /// busy calls it again when it finishes.
    private func advanceAIIfNeeded() {
        guard let opponent, interaction.isAITurn,
              !isOpponentThinking, !isAnimating, !isDriving else { return }

        isOpponentThinking = true
        hud.setBusy(true)
        board.clearHighlights()
        board.setSelectedTank(nil)
        board.setInspectedTank(nil)
        hud.update(with: interaction)      // the status line says Red is moving

        run(.sequence([
            .wait(forDuration: opponentDelay),
            .run { [weak self] in
                guard let self else { return }
                self.isOpponentThinking = false
                // Straight to `present` even with nothing to animate: a tank
                // holding its position produces no events, and treating that
                // as "nothing happened" would leave Red's turn half-played
                // with the board locked against the player.
                self.present(self.interaction.takeAIAction(with: opponent))
            },
        ]), withKey: Self.opponentTurnKey)
    }

    /// Drops a scheduled opponent turn, for a rematch mid-think.
    private func cancelScheduledAITurn() {
        removeAction(forKey: Self.opponentTurnKey)
        isOpponentThinking = false
    }

    private static let opponentTurnKey = "opponentTurn"

    private func startNewMatch() {
        guard let state = try? newGame() else { return }
        cancelScheduledAITurn()
        isDriving = false
        previewTankID = nil
        previewRoute = []
        interaction.reset(to: state)
        gameOver.hide()
        board.sync(with: state)
        refresh()
        advanceAIIfNeeded()
    }

    // MARK: - Drawing the current state

    /// Pushes the interaction's state into the board and the HUD. Cheap enough
    /// to call after every tap.
    private func refresh() {
        updatePreviewDrive()
        board.sync(with: interaction.state, keepingPositionOf: previewTankID)
        board.setSelectedTank(interaction.selectedTankID)
        // The inspected tank is always someone other than the selected one —
        // selecting clears it — and an aimed target already gets the attack
        // ring, so this is the only marker it needs.
        board.setInspectedTank(interaction.inspectedTankID)

        let attackTiles = interaction.targetableTankIDs.compactMap {
            interaction.state.tank($0)?.position
        }
        let aimedTile = interaction.aimedTargetID.flatMap { interaction.state.tank($0)?.position }
        board.showHighlights(moveTiles: interaction.moveHighlights,
                             attackTiles: attackTiles,
                             path: interaction.plannedPath,
                             aimedTile: aimedTile)

        hud.update(with: interaction)

        if case .finished(let result) = interaction.state.status {
            board.clearHighlights()
            if gameOver.isHidden {
                gameOver.show(result: result, in: interaction.state)
            }
        }
    }

    // MARK: - Driving the selected tank to its planned tile

    /// Rolls the selected tank from wherever it is standing to the tile the
    /// player just picked. `PreviewRoute` works out the tiles still to drive.
    private func updatePreviewDrive() {
        guard let plan = interaction.plan else {
            recallPreviewedTank()
            return
        }
        if previewTankID != plan.tankID {
            recallPreviewedTank()         // a different tank was picked; send the old one home
            previewTankID = plan.tankID
        }

        // An empty planned path means "staying put", i.e. the route is just the
        // tank's own tile.
        let current = previewRoute.isEmpty ? [plan.origin] : previewRoute
        let planned = interaction.plannedPath
        let target = planned.isEmpty ? [plan.origin] : planned
        previewRoute = target

        drive(tankID: plan.tankID, through: PreviewRoute.tiles(from: current, to: target))
    }

    /// Drives the previewed tank back to the tile it really occupies and forgets
    /// it, for a cancelled selection or a switch to another tank.
    private func recallPreviewedTank() {
        if let tankID = previewTankID, previewRoute.count > 1 {
            drive(tankID: tankID, through: Array(previewRoute.reversed().dropFirst()))
        }
        previewTankID = nil
        previewRoute = []
    }

    /// Rolls a tank through `tiles`, holding input until it arrives.
    private func drive(tankID: TankID, through tiles: [Position]) {
        guard !tiles.isEmpty else { return }
        isDriving = true
        hud.setBusy(true)
        board.drivePreview(tankID: tankID, through: tiles) { [weak self] in
            guard let self else { return }
            self.isDriving = false
            self.hud.setBusy(false)
        }
    }

    /// Parks the previewed tank on its planned tile and forgets it, so the
    /// committed `.moved` event does not drive the same route a second time.
    private func settlePreviewedTank() {
        if let tankID = previewTankID, let tile = previewRoute.last {
            board.finishPreview(tankID: tankID, at: tile)
        }
        // finishPreview cuts the drive short, so its completion never runs.
        isDriving = false
        previewTankID = nil
        previewRoute = []
    }

    // MARK: - Platform touch plumbing

    #if canImport(UIKit)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleTap(atScenePoint: touch.location(in: self))
    }
    #elseif canImport(AppKit)
    public override func mouseDown(with event: NSEvent) {
        handleTap(atScenePoint: event.location(in: self))
    }
    #endif

    // MARK: - Hooks for tests

    /// The state as the player currently sees it.
    public var currentState: GameState { interaction.state }

    /// Drives the scene exactly as a tap would, for tests and previews.
    public func simulateTap(onTile tile: Position) {
        tapBoard(tile)
    }

    /// Ends Blue's turn exactly as the Pass button does, for tests.
    public func simulatePass() {
        commit { $0.pass() }
    }

    /// Spends the selected tank's action with its planned move only, exactly
    /// as the Wait button does, for tests.
    public func simulateWait() {
        commit { $0.wait() }
    }

    /// Whether the board is waiting on Red rather than on the player.
    ///
    /// Note that this goes false the moment Red's action is applied, while its
    /// move is still animating — use `isAcceptingInput` to know when the board
    /// is ready for a tap.
    public var isOpponentTurn: Bool { interaction.isAITurn }

    /// Whether a tap would do anything right now: the match is live, nothing is
    /// animating, and the board is not waiting on Red.
    public var isAcceptingInput: Bool { !isBusy && !interaction.isOver }
}

extension Array where Element == GameEvent {
    /// Whether this batch of events drove the given tank anywhere.
    func moves(tankID: TankID) -> Bool {
        contains {
            if case .moved(let id, _) = $0 { return id == tankID }
            return false
        }
    }
}
