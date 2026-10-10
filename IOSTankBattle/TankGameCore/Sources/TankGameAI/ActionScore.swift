/// A candidate's score, kept broken down by term instead of collapsed into one
/// number. Tuning the AI means asking "why did it do THAT?", and the answer is
/// always which term dominated.
public struct ActionScore: Equatable, Sendable {
    /// Damage dealt to the target.
    public var damage: Double = 0
    /// Bonus for destroying the target.
    public var kill: Double = 0
    /// Damage taken from the counterattack (negative).
    public var counter: Double = 0
    /// Losing the acting tank to the counterattack (negative).
    public var loss: Double = 0
    /// Ending the match this turn (positive to win, negative to lose).
    public var outcome: Double = 0
    /// Enemy firepower gained or escaped at the destination.
    public var exposure: Double = 0
    /// Ground closed on the nearest enemy.
    public var approach: Double = 0
    /// HP and ammo regained on the own supply tile.
    public var supply: Double = 0
    /// Pass score and random jitter.
    public var bias: Double = 0

    public var total: Double {
        damage + kill + counter + loss + outcome + exposure + approach + supply + bias
    }

    /// Only the terms that did something, for debug output and failing tests.
    public var breakdown: String {
        let terms: [(String, Double)] = [
            ("damage", damage), ("kill", kill), ("counter", counter), ("loss", loss),
            ("outcome", outcome), ("exposure", exposure), ("approach", approach),
            ("supply", supply), ("bias", bias),
        ]
        let parts = terms
            .filter { $0.1 != 0 }
            .map { "\($0.0) \(String(format: "%+.2f", $0.1))" }
        return "\(String(format: "%.2f", total)) [\(parts.joined(separator: " "))]"
    }
}
