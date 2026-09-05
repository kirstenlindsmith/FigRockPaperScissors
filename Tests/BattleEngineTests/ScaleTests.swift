import Foundation
import Testing

@_spi(Instrumentation) import BattleEngine
@_spi(Instrumentation) import BattleFixtures

@Suite(.enabled(if: ProcessInfo.processInfo.environment["BATTLE_SCALE"] != nil))
struct ScaleTests {
    @Test(arguments: Armies.allCases)
    func everyBattleOfTheMatrixEndsWithOneKindStanding(armies: Armies) {
        for (soldiers, seeds) in [(300, UInt64(48)), (1500, UInt64(16)), (6000, UInt64(4))] {
            for seed in UInt64(1)...seeds {
                let battle = Battle(Fixtures.setup(armies, soldiers: soldiers, seed: seed))
                #expect(battle.runToEnd(within: Gate.resolutionTicks(soldiers: soldiers)))
            }
        }
    }

    @Test(arguments: Armies.allCases)
    func theEndgameCrowdIsPackedNotPooled(armies: Armies) {
        let battle = Battle(Fixtures.setup(armies, soldiers: 6000, seed: 1))
        var densest = 0
        var half = 0.0
        var mean = Float.infinity
        let body = battle.scale.body
        while !battle.census.isOver && battle.tickCount < Gate.resolutionTicks(soldiers: 6000) {
            battle.tick()
            densest = max(densest, battle.densestCell())
            if battle.tickCount % 100 == 0 {
                let spacing = battle.spacingNow()
                half = max(half, spacing.withinHalfBody)
                mean = min(mean, spacing.mean / body)
            }
        }
        #expect(battle.census.isOver)
        #expect(densest <= Gate.densestCell)
        #expect(half <= Gate.shareWithinHalfABody)
        #expect(mean >= Gate.meanNearestNeighbourInBodies)
        #expect(battle.longestSearchedRow <= Battle.candidateCap)
        #expect(battle.worstVisitsForOneSoldier <= Gate.visitsForOneSoldier)
    }

    @Test(arguments: [UInt64(1), 3])
    func theCrowdThatMopsUpTheLargestArmyIsPackedNotPooled(seed: UInt64) {
        let battle = Battle(Fixtures.setup(.lopsided, soldiers: 24000, seed: seed))
        var densest = 0
        var half = 0.0
        var mean = Float.infinity
        let body = battle.scale.body
        while !battle.census.isOver && battle.tickCount < Gate.resolutionTicks(soldiers: 24000) {
            battle.tick()
            densest = max(densest, battle.densestCell())
            if battle.tickCount % 100 == 0 {
                let spacing = battle.spacingNow()
                half = max(half, spacing.withinHalfBody)
                mean = min(mean, spacing.mean / body)
            }
        }
        #expect(battle.census.isOver)
        #expect(densest <= Gate.densestCell)
        #expect(half <= Gate.shareWithinHalfABody)
        #expect(mean >= Gate.meanNearestNeighbourInBodies)
        #expect(battle.longestSearchedRow <= Battle.candidateCap)
    }

    @Test(arguments: screens)
    func aGivenPileOpensOnEveryScreenTheSurfaceAdmits(aspect: Float) {
        let opened = CrowdTests.opening(
            pileOnAPoint(300, aspect: aspect),
            aspect: aspect,
            within: Gate.pileOpensOnAnyScreenBy
        )
        #expect(opened.pooled)
        #expect(opened.lastBreach <= Gate.pileOpensOnAnyScreenBy)
        #expect(opened.cleanSamples > 0)
    }

    @Test(arguments: screens)
    func aGivenCrowdInACornerOpensOnEveryScreenTheSurfaceAdmits(aspect: Float) {
        let opened = CrowdTests.opening(
            pileInACorner(300),
            aspect: aspect,
            within: Gate.cornerPileOpensOnAnyScreenBy
        )
        #expect(opened.pooled)
        #expect(opened.lastBreach <= Gate.cornerPileOpensOnAnyScreenBy)
        #expect(opened.cleanSamples > 0)
    }

    @Test func aGivenCrowdTenTimesDenserStillOpens() {
        let point = CrowdTests.opening(
            pileOnAPoint(3_000), aspect: Fixtures.phoneAspect, within: Gate.pileOpensOnAnyScreenBy
        )
        #expect(point.pooled)
        #expect(point.lastBreach <= Gate.pileOpensOnAnyScreenBy)
        #expect(point.cleanSamples > 0)
        let corner = CrowdTests.opening(
            pileInACorner(3_000),
            aspect: Fixtures.phoneAspect,
            within: Gate.cornerPileOpensOnAnyScreenBy
        )
        #expect(corner.pooled)
        #expect(corner.lastBreach <= Gate.cornerPileOpensOnAnyScreenBy)
        #expect(corner.cleanSamples > 0)
    }

    @Test func aCrowdWithoutTheSolvePools() {
        var densest = 0
        var half = 0.0
        for seed in UInt64(1)...2 {
            let battle = Battle(
                Fixtures.setup(.even, soldiers: 6000, seed: seed),
                constraintPasses: 1,
                overlapPasses: 0
            )
            while !battle.census.isOver && battle.tickCount < Gate.resolutionTicks(soldiers: 6000) {
                battle.tick()
                densest = max(densest, battle.densestCell())
                if battle.tickCount % 100 == 0 {
                    half = max(half, battle.spacingNow().withinHalfBody)
                }
            }
        }
        #expect(densest > Gate.densestCell)
        #expect(half > Gate.shareWithinHalfABody)
    }

    @Test(arguments: Armies.allCases)
    func theSearchHoldsWhereTheArmiesAreLargest(armies: Armies) {
        let battle = Battle(Fixtures.setup(armies, soldiers: 24000, seed: 1))
        for instant in [64, 512, 4096] {
            while battle.tickCount < instant && !battle.census.isOver { battle.tick() }
            let audit = battle.auditSearch(stride: 37)
            #expect(audit.blinded == 0)
            #expect(audit.identityBroken == 0)
            #expect(audit.worstTargetRatio <= Gate.targetDistanceOverNearest)
            #expect(audit.widestDecidingTie <= Gate.decidingTie)
        }
    }

    @Test func theWorkPerSoldierDoesNotGrowWithTheLargestArmies() {
        var perSoldier: [Double] = []
        for soldiers in [8000, 64000] {
            let battle = Battle(Fixtures.setup(.even, soldiers: soldiers, seed: 1))
            battle.run(ticks: 60)
            #expect(battle.worstVisitsForOneSoldier <= Gate.visitsForOneSoldier)
            perSoldier.append(Double(battle.visits) / Double(soldiers * battle.tickCount))
        }
        #expect(perSoldier[1] / perSoldier[0] < Gate.visitsPerSoldierGrowth)
    }

    @Test func noKindIsTheEnginesFavouriteOverThreeHundredSeeds() {
        let seeds = 300
        let won = wins(soldiers: 300, seeds: seeds)
        let band = Gate.winnerShareBand(seeds: seeds)
        #expect(won.reduce(0, +) == seeds)
        #expect(band.contains(Double(won.max()!) / Double(seeds)))
        #expect(band.contains(Double(won.min()!) / Double(seeds)))
    }

    @Test(arguments: [300, 1500])
    func theMedianBattleSurges(soldiers: Int) {
        var surges: [Int] = []
        var hands: [Double] = []
        for seed in UInt64(1)...16 {
            let battle = Battle(Fixtures.setup(.even, soldiers: soldiers, seed: seed))
            var watcher = Watcher(battle)
            while !battle.census.isOver && battle.tickCount < Gate.resolutionTicks(soldiers: soldiers) {
                battle.tick()
                watcher.observe()
            }
            #expect(battle.census.isOver)
            surges.append(watcher.surges)
            hands.append(watcher.handChangesPerSoldier)
            #expect(watcher.handChangesPerSoldier >= Gate.handChangesPerSoldier)
            if watcher.handChangesPerSoldier >= Gate.churnThatNeedsLegibility {
                #expect(watcher.meanKindLifetimeInSeconds >= Gate.kindLifetimeInSeconds)
            }
        }
        #expect(surges.sorted()[surges.count / 2] >= Gate.surgesInTheMedianBattle)
        #expect(hands.sorted()[hands.count / 2] >= Gate.handChangesPerSoldier * 2)
    }
}
