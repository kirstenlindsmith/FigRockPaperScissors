@_spi(Instrumentation) import BattleFixtures
import Glibc

@_spi(Instrumentation) import BattleEngine

func steeringReport(_ battle: Battle, stride: Int, rings: Int?) -> String {
    let audit = battle.auditSearch(stride: stride, rings: rings)
    var headings: [Double] = []
    var ratios: [Double] = []
    for sample in battle.steeringSamples(stride: stride, rings: rings) {
        let truth = battle.bruteForceTruth(for: sample)
        guard truth.chasing == sample.chasing, sample.hasTarget, let target = truth.target else {
            continue
        }
        if target.distance > 0 { ratios.append(Double(sample.targetDistance / target.distance)) }
        let mine = sample.chasing
            ? sample.target - sample.position
            : sample.position - sample.target
        let real = sample.chasing
            ? target.position - sample.position
            : sample.position - target.position
        let lengths = (
            (mine.x * mine.x + mine.y * mine.y).squareRoot(),
            (real.x * real.x + real.y * real.y).squareRoot()
        )
        if lengths.0 > 0 && lengths.1 > 0 {
            var cosine = Double((mine.x * real.x + mine.y * real.y) / (lengths.0 * lengths.1))
            cosine = min(1, max(-1, cosine))
            headings.append(acos(cosine) * 180 / 3.141592653589793)
        }
    }
    headings.sort()
    ratios.sort()
    let meanHeading = headings.isEmpty ? 0 : headings.reduce(0, +) / Double(headings.count)
    let meanRatio = ratios.isEmpty ? 0 : ratios.reduce(0, +) / Double(ratios.count)
    return "samples=\(audit.samples) compared=\(audit.compared) "
        + "insideReach=\(audit.nearestInsideReach) identityBroken=\(audit.identityBroken) "
        + "blinded=\(audit.blinded) "
        + "exactTargetPct=\(show(audit.exactTargetShare * 100, 2)) "
        + "meanDeg=\(show(meanHeading, 2)) medDeg=\(show(quantile(headings, 0.5), 2)) "
        + "p99Deg=\(show(quantile(headings, 0.99), 2)) worstDeg=\(show(headings.last ?? 0, 2)) "
        + "ratioMean=\(show(meanRatio, 4)) ratioP99=\(show(quantile(ratios, 0.99), 4)) "
        + "ratioMax=\(show(audit.worstTargetRatio, 4)) "
        + "ratioMaxAt=\(show(audit.trueDistanceAtWorstRatio, 2)) "
        + "decisionDiffersPct=\(show(audit.decisionDifferenceShare * 100, 3)) "
        + "tieMax=\(show(audit.widestDecidingTie, 4)) longestRow=\(battle.longestSearchedRow)"
}
