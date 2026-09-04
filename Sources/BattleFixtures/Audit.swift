@_spi(Instrumentation) import BattleEngine

public struct Nearest: Sendable {
    public var distance: Float
    public var position: SIMD2<Float>
}

public struct Truth: Sendable {
    public var prey: Nearest?
    public var predator: Nearest?

    public var chasing: Bool {
        guard let prey else { return false }
        guard let predator else { return true }
        return prey.distance <= predator.distance
    }

    public var target: Nearest? { chasing ? prey : predator }
}

public struct SearchAudit: Sendable {
    public var samples = 0
    public var compared = 0
    public var nearestInsideReach = 0
    public var blinded = 0
    public var identityBroken = 0
    public var exactTargets = 0
    public var worstTargetRatio = 1.0
    public var trueDistanceAtWorstRatio = 0.0
    public var decisionsDiffering = 0
    public var widestDecidingTie = 0.0

    public var exactTargetShare: Double {
        compared > 0 ? Double(exactTargets) / Double(compared) : 0
    }

    public var decisionDifferenceShare: Double {
        samples > 0 ? Double(decisionsDiffering) / Double(samples) : 0
    }
}

extension Battle {
    @_spi(Instrumentation) public func bruteForceTruth(for sample: SteeringSample) -> Truth {
        var prey: Nearest?
        var predator: Nearest?
        let preyKind = sample.kind.beats
        let predatorKind = sample.kind.beats.beats
        withSoldiers { positions, kinds in
            var preyDistance = Float.infinity
            var predatorDistance = Float.infinity
            for j in 0..<positions.count where j != sample.soldier {
                let delta = positions[j] - sample.position
                let d = delta.x * delta.x + delta.y * delta.y
                if kinds[j] == preyKind {
                    if d < preyDistance {
                        preyDistance = d
                        prey = Nearest(distance: d, position: positions[j])
                    }
                } else if kinds[j] == predatorKind {
                    if d < predatorDistance {
                        predatorDistance = d
                        predator = Nearest(distance: d, position: positions[j])
                    }
                }
            }
        }
        if let found = prey { prey = Nearest(distance: found.distance.squareRoot(), position: found.position) }
        if let found = predator {
            predator = Nearest(distance: found.distance.squareRoot(), position: found.position)
        }
        return Truth(prey: prey, predator: predator)
    }

    @_spi(Instrumentation) public func auditSearch(stride: Int, rings: Int? = nil) -> SearchAudit {
        var audit = SearchAudit()
        let scale = self.scale
        for sample in steeringSamples(stride: stride, rings: rings) {
            let truth = bruteForceTruth(for: sample)
            audit.samples += 1
            if !sample.readEverything { audit.blinded += 1 }
            if let prey = truth.prey, prey.distance < sample.coveredExactly {
                audit.nearestInsideReach += 1
                if sample.searchedPreyDistance > prey.distance { audit.identityBroken += 1 }
            }
            if let predator = truth.predator, predator.distance < sample.coveredExactly {
                audit.nearestInsideReach += 1
                if sample.searchedPredatorDistance > predator.distance { audit.identityBroken += 1 }
            }
            if truth.chasing != sample.chasing {
                audit.decisionsDiffering += 1
                if let prey = truth.prey, let predator = truth.predator {
                    let gap = abs(Double(prey.distance) - Double(predator.distance))
                        / max(1e-12, Double(min(prey.distance, predator.distance)))
                    audit.widestDecidingTie = max(audit.widestDecidingTie, gap)
                } else {
                    audit.widestDecidingTie = .infinity
                }
                continue
            }
            guard sample.hasTarget, let target = truth.target else { continue }
            audit.compared += 1
            if sample.targetDistance <= target.distance { audit.exactTargets += 1 }
            if target.distance > 0 {
                let ratio = Double(sample.targetDistance / target.distance)
                if ratio > audit.worstTargetRatio {
                    audit.worstTargetRatio = ratio
                    audit.trueDistanceAtWorstRatio = Double(target.distance / scale.spacing)
                }
            }
        }
        return audit
    }
}
