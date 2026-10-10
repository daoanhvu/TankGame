import TankGameCore

/// Scores one candidate action on its immediate merits only — no look-ahead.
///
/// The terms are the ones milestone 3 calls for: damage dealt + kill bonus
/// - counter damage taken - exposure + approach + supply. Two of them are
/// deliberately measured as a CHANGE rather than an absolute:
///
/// - **exposure**: how much hotter the destination is than the tile the tank
///   stands on now. Absolute exposure would punish a tank for where the match
///   had already put it, and since one score ranks candidates across all five
///   tanks, that would quietly bias every turn towards whichever tank happened
///   to be furthest from the fighting.
/// - **approach**: ground closed, for the same reason.
///
/// The balance between those two is what decides whether the AI plays at all.
/// Weighted equally, two one-ply brains advance to the edge of each other's
/// range and stop: every step into contact costs more than the ground is
/// worth, so nobody ever fires and the match runs out of rounds at full HP.
/// So `exposurePenalty` is deliberately small — it picks the quieter of two
/// otherwise similar tiles rather than deciding whether to engage — and
/// `lethalExposurePenalty` is the one brake big enough to stop a tank, which
/// is why it only trips for a tank that a single shot could kill.
///
/// Everything else (damage, kills, the counterattack) comes from
/// `Rules.preview`, so the numbers the AI reasons about are exactly the ones
/// the player sees in the damage preview.
public struct GreedyEvaluator: Sendable {

    public var weights: AIWeights

    public init(weights: AIWeights = .standard) {
        self.weights = weights
    }

    /// Scores a candidate for `state.currentSide`.
    ///
    /// - Parameter context: the threat and distance maps for the acting side,
    ///   built once per decision. Pass nil only in tests or one-off calls;
    ///   rebuilding it per candidate is wasteful.
    public func score(_ candidate: ActionGenerator.Candidate,
                      in state: GameState,
                      context: ScoringContext? = nil) -> ActionScore {
        var score = ActionScore()

        guard let tank = candidate.tank,
              let moved = candidate.movedTank,
              let destination = candidate.destination else {
            score.bias = weights.passScore          // `.pass`
            return score
        }

        let context = context ?? ScoringContext(for: tank.side, in: state)
        let threat = context.threat
        let enemies = state.aliveTanks(of: tank.side.opponent)
        let stats = state.stats(of: tank)

        // MARK: Shooting

        var attackerHP = moved.hp
        if let target = candidate.target {
            let shot = Rules.preview(attacker: moved, target: target, in: state)
            score.damage = Double(shot.damage) * weights.damageDealt
            if shot.targetDestroyed {
                score.kill = weights.killBonus
                // Taking the last enemy tank ends the match (task 7), which is
                // worth more than any amount of positioning.
                if enemies.count == 1 { score.outcome += weights.winBonus }
            }
            score.counter = -Double(shot.counterDamage) * weights.counterDamage
            if shot.attackerDestroyed {
                score.loss = -weights.lossPenalty
                // Trading our last tank away loses the match just as surely.
                if state.aliveTanks(of: tank.side).count == 1 {
                    score.outcome -= weights.winBonus
                }
            }
            attackerHP = moved.hp - shot.counterDamage
        }

        // A tank that is about to die where it stands has no position to judge,
        // and the counterattack already paid for it.
        guard attackerHP > 0 else { return score }

        // MARK: Positioning

        // Exposure is judged on the tank as it will be (post-counterattack HP),
        // because what matters is whether the enemy can finish it next turn.
        var survivor = moved
        survivor.hp = attackerHP
        let before = threat.strongestShot(at: tank.position)
        let after = threat.strongestShot(at: destination)
        let delta = after - before
        score.exposure = delta >= 0
            ? -Double(delta) * weights.exposurePenalty
            : Double(-delta) * weights.exposureRelief

        // Whether one enemy action can finish this tank off is a step change,
        // not one more point of damage, and it is the one positional term
        // allowed to overrule the urge to advance. Symmetric on purpose:
        // breaking out of a lethal envelope is worth as much as walking into
        // one costs, which is what makes wounded tanks disengage and head for
        // the supply tile instead of trading themselves away.
        let lethalBefore = threat.isLethal(for: tank, at: tank.position)
        let lethalAfter = threat.isLethal(for: survivor, at: destination)
        if lethalAfter, !lethalBefore {
            score.exposure -= weights.lethalExposurePenalty
        } else if lethalBefore, !lethalAfter {
            score.exposure += weights.lethalExposurePenalty
        }

        // Approach: ground gained on the nearest enemy, measured as driving
        // distance (see `DistanceField` — a straight line reads a detour round
        // the river as no progress at all), and weighted by how much fight the
        // tank has left. A tank down to its last HP or out of shells has no
        // business leading the advance, and zeroing its interest in the enemy
        // is what leaves the supply pull below free to send it home.
        let readiness = survivor.hasAmmo
            ? Double(survivor.hp) / Double(stats.maxHP)
            : 0
        if !enemies.isEmpty {
            let closed = context.toEnemy.progress(from: tank.position, to: destination)
            score.approach = Double(closed) * weights.approachBonus * readiness
        }

        // MARK: Supply
        //
        // `Rules.tankAfterMove` has already applied the refill, so the gain is
        // simply the difference — which is 0 for a healthy tank and 0 for one
        // that is merely standing on the tile without having arrived.
        let hpGain = moved.hp - tank.hp
        let ammoGain = moved.ammo - tank.ammo
        score.supply = Double(hpGain) * weights.supplyRepairBonus
            + Double(ammoGain) * weights.supplyRearmBonus

        // Arriving is several turns away for most of the map, so the trip has
        // to be worth something on its own: ground covered towards the depot,
        // scaled by how badly this tank needs what is there. `moved` already
        // includes the refill, so the tank that just arrived needs nothing and
        // gets no further pull.
        let need = max(Double(stats.maxHP - moved.hp) / Double(stats.maxHP),
                       stats.maxAmmo > 0
                           ? Double(stats.maxAmmo - moved.ammo) / Double(stats.maxAmmo)
                           : 0)
        if need > 0, let toDepot = context.toDepot {
            let closed = toDepot.progress(from: tank.position, to: destination)
            score.supply += Double(closed) * weights.supplyApproachBonus * need
        }

        return score
    }
}
