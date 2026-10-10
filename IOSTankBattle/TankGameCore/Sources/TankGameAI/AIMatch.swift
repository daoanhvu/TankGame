import TankGameCore

/// Plays a match out with no UI: an AI on either side, as fast as the rules
/// can apply actions.
///
/// Two jobs. It is how the AI is tested (play 100 matches, assert the greedy
/// brain beats the random one), and it is how balance gets measured in
/// milestone 4 — self-play says more about the tank stats than any amount of
/// reading the table does.
///
/// It is also the reference for driving an AI turn from the scene: ask for an
/// action, apply it, animate the events.
public enum AIMatch {

    public struct Outcome: Sendable {
        /// The finished state. `status` carries the result.
        public let state: GameState
        public let result: GameResult?
        /// Actions taken, in order, oldest first.
        public let actions: [Action]
        /// Set if a brain offered an action the rules rejected and the driver
        /// had to fall back to `.pass`. Should always be empty; it is here so
        /// that a generator bug shows up as a test failure, not as a hang.
        public let illegalActions: [Action]

        public var turns: Int { actions.count }
    }

    /// Asks one AI for an action and applies it, falling back to `.pass` if the
    /// rules reject it. The single place where an AI's choice meets the rules.
    public static func takeTurn(_ ai: TankAI, in state: GameState)
        -> (state: GameState, events: [GameEvent], action: Action, wasIllegal: Bool) {
        let chosen = ai.chooseAction(in: state)
        if let result = try? Rules.apply(chosen, to: state) {
            return (result.state, result.events, chosen, false)
        }
        // A brain that offers something illegal must not stall the game, but it
        // also must not be papered over: `wasIllegal` carries the complaint up.
        let fallback = (try? Rules.apply(.pass, to: state))
        return (fallback?.state ?? state, fallback?.events ?? [], chosen, true)
    }

    /// Plays until the rules end the match.
    ///
    /// - Parameter turnLimit: a hard stop in case a rules change ever lets a
    ///   match run forever. Reaching it is a bug, not a draw.
    public static func play(_ initial: GameState,
                            player: TankAI,
                            ai: TankAI,
                            turnLimit: Int = 10_000) -> Outcome {
        var state = initial
        var actions: [Action] = []
        var illegal: [Action] = []

        while !state.isOver, actions.count < turnLimit {
            let brain: TankAI = state.currentSide == .player ? player : ai
            let turn = takeTurn(brain, in: state)
            state = turn.state
            actions.append(turn.action)
            if turn.wasIllegal { illegal.append(turn.action) }
        }

        var result: GameResult?
        if case .finished(let finished) = state.status { result = finished }
        return Outcome(state: state, result: result, actions: actions, illegalActions: illegal)
    }

    /// Wins, losses and draws over `count` matches, for tuning weights.
    /// Seeds are varied per match so jittered brains explore different lines;
    /// without jitter every match is identical, which is itself a useful check.
    public static func tally(_ initial: GameState,
                             player: TankAI,
                             ai: TankAI,
                             count: Int) -> Record {
        var record = Record()
        for _ in 0..<count {
            let outcome = play(initial, player: player, ai: ai)
            record.add(outcome.result)
        }
        return record
    }

    public struct Record: Equatable, Sendable, CustomStringConvertible {
        public var playerWins = 0
        public var aiWins = 0
        public var draws = 0

        public var total: Int { playerWins + aiWins + draws }

        public mutating func add(_ result: GameResult?) {
            switch result {
            case .win(.player, _): playerWins += 1
            case .win(.ai, _): aiWins += 1
            case .draw: draws += 1
            case nil: break
            }
        }

        public var description: String {
            "player \(playerWins) - ai \(aiWins) - draw \(draws) of \(total)"
        }
    }
}
