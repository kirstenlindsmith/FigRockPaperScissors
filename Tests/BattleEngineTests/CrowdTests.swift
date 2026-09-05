import BattleFixtures
import Testing

@_spi(Instrumentation) import BattleEngine

@Suite struct CrowdTests {
    static func penned(flock: Int = 300, pressers: Int = 6, constraintPasses: Int = Battle.constraintPasses) -> Battle {
        let soldiers = flock + pressers
        let scale = Scale(soldiers: soldiers)
        let inset = scale.body * 0.5
        let step = 1.15 * scale.body
        let columns = 20
        var placing: [(SIMD2<Float>, Kind)] = []
        for i in 0..<flock {
            placing.append((
                SIMD2(inset + Float(i % columns) * step, inset + Float(i / columns) * step), .rock
            ))
        }
        let edge = inset + Float(columns) * step
        for i in 0..<pressers {
            placing.append((SIMD2(edge + step, inset + Float(i) * step * 2), .paper))
        }
        return Battle(
            placing: placing,
            aspect: Fixtures.phoneAspect,
            constraintPasses: constraintPasses
        )
    }

    static func crush(_ battle: Battle, ticks: Int = 500)
        -> (densest: Int, half: Double, closest: Float, mean: Float)
    {
        let body = battle.scale.body
        var densest = 0
        var half = 0.0
        var closest = Float.infinity
        var mean = Float.infinity
        var run = 0
        while !battle.census.isOver && run < ticks {
            battle.tick()
            run += 1
            if run < 20 { continue }
            densest = max(densest, battle.densestCell())
            let spacing = battle.spacingNow()
            half = max(half, spacing.withinHalfBody)
            closest = min(closest, spacing.closest / body)
            mean = min(mean, spacing.mean / body)
        }
        return (densest, half, closest, mean)
    }

    static func opening(_ field: [(SIMD2<Float>, Kind)], aspect: Float, within budget: Int)
        -> (pooled: Bool, lastBreach: Int, cleanSamples: Int)
    {
        let battle = Battle(placing: field, aspect: aspect)
        let body = battle.scale.body
        var pooled = false
        var samples = 0
        var lastBreach = 0
        var clean = 0
        var run = 0
        while !battle.census.isOver && run < budget + 4 * Gate.crowdSample {
            battle.tick()
            run += 1
            guard run % Gate.crowdSample == 0 else { continue }
            let spacing = battle.spacingNow()
            let breached = battle.densestCell() > Gate.densestCell
                || spacing.withinHalfBody > Gate.shareWithinHalfABody
                || spacing.mean / body < Gate.meanNearestNeighbourInBodies
            if samples == 0 { pooled = breached }
            samples += 1
            if breached {
                lastBreach = run
                clean = 0
            } else {
                clean += 1
            }
        }
        return (pooled, lastBreach, clean)
    }

    @Test func aGivenPileOpensIntoTheCrowdABattleKeeps() {
        let opened = CrowdTests.opening(
            pileOnAPoint(300), aspect: Fixtures.phoneAspect, within: Gate.pileOpensOnAPhoneBy
        )
        #expect(opened.pooled)
        #expect(opened.lastBreach <= Gate.pileOpensOnAPhoneBy)
        #expect(opened.cleanSamples > 0)
    }

    @Test func aGivenCrowdInACornerOpensIntoTheCrowdABattleKeeps() {
        let opened = CrowdTests.opening(
            pileInACorner(300),
            aspect: Fixtures.phoneAspect,
            within: Gate.cornerPileOpensOnAPhoneBy
        )
        #expect(opened.pooled)
        #expect(opened.lastBreach <= Gate.cornerPileOpensOnAPhoneBy)
        #expect(opened.cleanSamples > 0)
    }

    @Test func armiesDrawnUpNeverOverlap() {
        let aspects: [Float] = [0.46, 1, 19.5 / 9, 1e-30, 1e30]
        for aspect in aspects {
            for soldiers in [3, 60, 1500] {
                for seed in UInt64(1)...6 {
                    let battle = Battle(
                        Fixtures.setup(.even, soldiers: soldiers, seed: seed, aspect: aspect)
                    )
                    let spacing = battle.spacingNow()
                    #expect(spacing.withinBody == 0)
                    #expect(spacing.closest >= battle.scale.body)
                }
            }
        }
    }

    @Test func aCrowdPressedAgainstAWallKeepsItsBodiesApart() {
        let crowded = CrowdTests.crush(CrowdTests.penned())
        #expect(crowded.densest <= Gate.densestCell)
        #expect(crowded.half <= Gate.shareWithinHalfABody)
        #expect(crowded.mean >= Gate.meanNearestNeighbourInBodies)
    }

    @Test func stoppingTheSolveLetsAPressedCrowdCloseUp() {
        let solved = CrowdTests.crush(CrowdTests.penned())
        let stopped = CrowdTests.crush(CrowdTests.penned(constraintPasses: 1))
        #expect(stopped.closest < solved.closest)
    }

    @Test func theCrowdOfAWholeBattleNeverPools() {
        for (armies, seed) in [(Armies.even, UInt64(2))] {
            let battle = Battle(Fixtures.setup(armies, soldiers: 600, seed: seed))
            var worstDensest = 0
            var worstHalf = 0.0
            var worstMean = Float.infinity
            let body = battle.scale.body
            while !battle.census.isOver && battle.tickCount < Gate.resolutionTicks(soldiers: 600) {
                battle.tick()
                worstDensest = max(worstDensest, battle.densestCell())
                if battle.tickCount % Gate.crowdSample == 0 {
                    let spacing = battle.spacingNow()
                    worstHalf = max(worstHalf, spacing.withinHalfBody)
                    worstMean = min(worstMean, spacing.mean / body)
                }
            }
            #expect(battle.census.isOver)
            #expect(worstDensest <= Gate.densestCell)
            #expect(worstHalf <= Gate.shareWithinHalfABody)
            #expect(worstMean >= Gate.meanNearestNeighbourInBodies)
        }
    }
}
