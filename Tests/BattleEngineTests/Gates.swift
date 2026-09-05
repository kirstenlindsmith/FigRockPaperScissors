@_spi(Instrumentation) import BattleEngine

enum Gate {
    static let coordinateRoundings: Float = 4

    static let crowdSample = 25
    static let pileOpensOnAPhoneBy = 250
    static let cornerPileOpensOnAPhoneBy = 1_000
    static let pileOpensOnAnyScreenBy = 2_000
    static let cornerPileOpensOnAnyScreenBy = 6_000

    static let densestCell = 64
    static let shareWithinHalfABody = 0.01
    static let meanNearestNeighbourInBodies: Float = 0.9

    static let targetDistanceOverNearest = 1.5
    static let decidingTie = 0.25
    static let shallowSearchPenalty = 1.4
    static let visitsPerSoldierGrowth = 2.0
    static let smallestSizeForVisitGrowth = 1000
    static let visitsForOneSoldier = 192
    static let unconstrainedSoldiersSteeringAtTheTrueNearest = 0.9

    static let handChangesPerSoldier = 2.0
    static let surgesInEveryBattle = 1
    static let surgesInTheMedianBattle = 4
    static let kindLifetimeInSeconds = 0.4
    static let churnThatNeedsLegibility = 5.0

    static let winnerShareNoises = 4.0
    static let mixingNoises = 4.0
    static let latticeSitesPerSoldier = 1.0...Double(Battle.latticeSitesPerSoldierCeiling)
    static let shortestToLongestBattle = 2.0

    static func winnerShareBand(seeds: Int) -> ClosedRange<Double> {
        let third = 1.0 / 3
        let noise = (third * (1 - third) / Double(seeds)).squareRoot()
        return (third - winnerShareNoises * noise)...(third + winnerShareNoises * noise)
    }

    static func mixingBand(_ setup: Setup) -> ClosedRange<Double> {
        let total = Double(setup.count)
        var shares = 0.0
        for kind in Kind.allCases {
            let share = Double(setup[kind]) / total
            shares += share * share
        }
        let mixed = 1 - shares
        let noise = (mixed * (1 - mixed) / total).squareRoot()
        return (mixed - mixingNoises * noise)...(mixed + mixingNoises * noise)
    }

    static func resolutionTicks(soldiers: Int) -> Int {
        switch soldiers {
        case ..<10: 1_000
        case ..<50: 3_000
        case ..<200: 6_000
        case ..<600: 8_000
        case ..<3_000: 24_000
        default: 64_000
        }
    }
}
