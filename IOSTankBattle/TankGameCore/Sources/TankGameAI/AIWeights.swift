import Foundation
import TankGameCore

/// Every tunable number the greedy brain uses, in one Codable place — the same
/// rule `GameConfig` follows for balance: tuning the AI must never mean editing
/// its logic.
///
/// Scores are in "HP points" as a unit: a weight of 1 means one point of damage.
/// That keeps the terms comparable and makes the numbers readable while tuning.
public struct AIWeights: Codable, Equatable, Sendable {

    // MARK: Shooting

    /// Per point of damage dealt to an enemy.
    public var damageDealt: Double
    /// Flat bonus on top of the damage for destroying an enemy tank.
    public var killBonus: Double
    /// Per point of damage taken from the defender's counterattack.
    ///
    /// Below 1 on purpose, i.e. a point dealt is worth slightly more than a
    /// point taken. Priced at parity, every opening trade a light can make
    /// against a medium scores negative (3 out, 4 back) and the AI sits on a
    /// winning position refusing to fire, because one ply cannot see the
    /// teammate who finishes the target next turn. `lossPenalty` is what stops
    /// this from becoming a willingness to throw tanks away.
    public var counterDamage: Double
    /// Flat penalty for losing our own tank to that counterattack.
    public var lossPenalty: Double
    /// Flat bonus for an action that wipes out the last enemy tank.
    public var winBonus: Double

    // MARK: Positioning

    /// Per point of the biggest single enemy shot the destination tile newly
    /// exposes the tank to (see `ThreatMap.strongestShot(at:)`).
    ///
    /// Small on purpose. Its job is to pick the quieter of two similar tiles,
    /// not to decide whether to fight: priced anywhere near `approachBonus`,
    /// two of these brains stand just outside each other's range for forty
    /// rounds and draw at full HP.
    public var exposurePenalty: Double
    /// Per point of enemy firepower the tank escapes by moving.
    ///
    /// Deliberately smaller than `exposurePenalty`: credit for retreating has to
    /// be worth less than the cost of advancing, or a greedy brain spends the
    /// match shuffling in and out of cover instead of fighting.
    public var exposureRelief: Double
    /// Ending within one shot of death, when the tank is not already there —
    /// and, with the same weight, the credit for escaping that envelope.
    ///
    /// The one positional term big enough to overrule advancing, which is why
    /// it only applies to a tank a single enemy action could destroy. This is
    /// what makes healthy tanks press forward and wounded ones pull back.
    public var lethalExposurePenalty: Double
    /// Per tile of Manhattan distance closed to the nearest enemy, scaled by
    /// how much fight the tank has left in it (remaining HP, and nothing at
    /// all with an empty rack). This is what stops the AI from standing still
    /// when nothing is in range — and what keeps a shot-up tank from leading
    /// the charge.
    public var approachBonus: Double

    // MARK: Supply

    /// Per HP regained by arriving on the own supply tile.
    public var supplyRepairBonus: Double
    /// Per shell regained by arriving on the own supply tile.
    public var supplyRearmBonus: Double
    /// Per tile closed towards the own supply tile, scaled by how badly the
    /// tank needs it (its worst shortfall in HP or ammo, as a fraction).
    ///
    /// Without this, only the arriving step pays and a wounded tank three
    /// tiles from the depot has nothing pulling it home: it sits where it is
    /// for the rest of the match, too damaged to advance and unrewarded for
    /// retreating.
    public var supplyApproachBonus: Double

    // MARK: Tie-breaking

    /// Score given to `.pass`. Slightly negative so that any action worth
    /// nothing at all still beats doing nothing — passing then only happens
    /// when every move actively hurts.
    public var passScore: Double
    /// Random spread added to every candidate's score, in the same HP unit.
    /// 0 (the default) makes the AI fully deterministic; a small value keeps
    /// repeat matches from playing out identically.
    public var jitter: Double

    public init(damageDealt: Double = 1.0,
                killBonus: Double = 6.0,
                counterDamage: Double = 0.7,
                lossPenalty: Double = 8.0,
                winBonus: Double = 100.0,
                exposurePenalty: Double = 0.10,
                exposureRelief: Double = 0.05,
                lethalExposurePenalty: Double = 4.0,
                approachBonus: Double = 0.6,
                supplyRepairBonus: Double = 0.8,
                supplyRearmBonus: Double = 1.5,
                supplyApproachBonus: Double = 1.0,
                passScore: Double = -0.05,
                jitter: Double = 0) {
        self.damageDealt = damageDealt
        self.killBonus = killBonus
        self.counterDamage = counterDamage
        self.lossPenalty = lossPenalty
        self.winBonus = winBonus
        self.exposurePenalty = exposurePenalty
        self.exposureRelief = exposureRelief
        self.lethalExposurePenalty = lethalExposurePenalty
        self.approachBonus = approachBonus
        self.supplyRepairBonus = supplyRepairBonus
        self.supplyRearmBonus = supplyRearmBonus
        self.supplyApproachBonus = supplyApproachBonus
        self.passScore = passScore
        self.jitter = jitter
    }

    /// The tuning used for playtesting.
    public static let standard = AIWeights()

    /// Shoots whenever it can and walks straight at the enemy: no threat map,
    /// no retreating. Useful as an "easy" setting and as a sparring partner
    /// when measuring whether a smarter brain is actually better.
    public static let reckless = AIWeights(killBonus: 4,
                                           counterDamage: 0.4,
                                           lossPenalty: 2,
                                           exposurePenalty: 0,
                                           exposureRelief: 0,
                                           lethalExposurePenalty: 0,
                                           approachBonus: 1.0,
                                           supplyRepairBonus: 0.2,
                                           supplyRearmBonus: 0.5,
                                           supplyApproachBonus: 0.2)

    /// Trades damage only on favourable terms and hugs its own supply tile.
    public static let cautious = AIWeights(killBonus: 7,
                                           counterDamage: 1.6,
                                           lossPenalty: 14,
                                           exposurePenalty: 0.25,
                                           exposureRelief: 0.2,
                                           lethalExposurePenalty: 8,
                                           approachBonus: 0.45,
                                           supplyRepairBonus: 1.2,
                                           supplyRearmBonus: 2.0,
                                           supplyApproachBonus: 1.6)

    public static func load(fromJSON data: Data) throws -> AIWeights {
        try JSONDecoder().decode(AIWeights.self, from: data)
    }
}
