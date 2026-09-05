import BattleFixtures
import Testing

@_spi(Instrumentation) import BattleEngine

@Suite struct MotionTests {
    static let adversarial: [(Armies, Int, Float)] = [
        (.lopsided, 60, 19.5 / 9),
        (.even, 60, 19.5 / 9),
        (.even, 120, 19.5 / 9),
        (.even, 3, 1e-30),
        (.even, 3, 1e30),
        (.even, 6, 1e-30),
        (.lopsided, 60, 1e30),
        (.even, 300, 0.46),
    ]

    @Test(arguments: adversarial)
    func soldiersStayInTheArenaAndNeverLeapTickAfterTick(
        armies: Armies, soldiers: Int, aspect: Float
    ) {
        let battle = Battle(Fixtures.setup(armies, soldiers: soldiers, seed: 3, aspect: aspect))
        let cap = battle.scale.displacementCap + Gate.coordinateRoundings * battle.coordinateUlp
        var previous = battle.positionsNow
        var worst: Float = 0
        var ticks = 0
        while !battle.census.isOver && ticks < 4000 {
            battle.tick()
            ticks += 1
            let now = battle.positionsNow
            for i in 0..<now.count {
                #expect(now[i].x.isFinite && now[i].y.isFinite)
                #expect(now[i].x >= battle.insetLow.x && now[i].x <= battle.insetHigh.x)
                #expect(now[i].y >= battle.insetLow.y && now[i].y <= battle.insetHigh.y)
                let moved = now[i] - previous[i]
                let travelled = (moved.x * moved.x + moved.y * moved.y).squareRoot()
                worst = max(worst, travelled)
                #expect(travelled <= cap)
            }
            previous = now
        }
        #expect(worst > 0)
    }

    @Test(arguments: screens)
    func aBattleFoughtFromAGivenFieldStaysInsideTheArenaAndNeverLeaps(aspect: Float) {
        let fields = [
            wildField(aspect: aspect),
            pileOnAPoint(60, aspect: aspect),
            pileInACorner(60),
        ]
        for field in fields {
            let battle = Battle(placing: field, aspect: aspect)
            let cap = battle.scale.displacementCap
            let allowance = Gate.coordinateRoundings * battle.coordinateUlp
            var outside = 0
            var nonFinite = 0
            var leaps = 0
            var worst: Float = 0
            var previous = battle.positionsNow
            func inspect(_ now: [SIMD2<Float>]) {
                for i in 0..<now.count {
                    if !now[i].x.isFinite || !now[i].y.isFinite { nonFinite += 1 }
                    if now[i].x < battle.insetLow.x || now[i].x > battle.insetHigh.x
                        || now[i].y < battle.insetLow.y || now[i].y > battle.insetHigh.y {
                        outside += 1
                    }
                    let moved = now[i] - previous[i]
                    let travelled = (moved.x * moved.x + moved.y * moved.y).squareRoot()
                    if travelled > cap + allowance { leaps += 1 }
                    worst = max(worst, travelled)
                }
            }
            inspect(previous)
            var ticks = 0
            while !battle.census.isOver && ticks < 200 {
                battle.tick()
                ticks += 1
                let now = battle.positionsNow
                inspect(now)
                previous = now
            }
            #expect(outside == 0)
            #expect(nonFinite == 0)
            #expect(leaps == 0)
            #expect(worst >= cap - allowance)
            #expect(ticks > 0)
        }
    }

    @Test func lengthsHoldEachOtherApart() {
        for soldiers in [1, 2, 30, 6000, 1_000_000] {
            let scale = Scale(soldiers: soldiers)
            #expect(scale.body < scale.contact)
            #expect(scale.contact < scale.interaction)
            #expect(2 * scale.displacementCap < 1.4142135 * scale.contact)
            #expect(abs(scale.chaseStep - 0.25 * scale.contact) < 1e-6 * scale.contact)
            #expect(abs(scale.displacementCap - 2.4 * scale.chaseStep) < 1e-6 * scale.contact)
            #expect(abs(scale.fleeStep - 0.6 * scale.chaseStep) < 1e-6 * scale.contact)
            #expect(scale.fleeStep < scale.chaseStep)
            #expect(abs(scale.interaction - (scale.body + 2 * scale.chaseStep)) < 1e-6 * scale.contact)
        }
    }

    static let headings: [SIMD2<Float>] = (0..<16).map { step in
        let sixteenths: [Float] = [
            1, 0.9238795, 0.7071068, 0.3826834, 0, -0.3826834, -0.7071068, -0.9238795,
            -1, -0.9238795, -0.7071068, -0.3826834, 0, 0.3826834, 0.7071068, 0.9238795,
        ]
        return SIMD2(sixteenths[step], sixteenths[(step + 12) % 16])
    }

    @Test func contactIsTheSameInEveryDirection() {
        let scale = Scale(soldiers: 100)
        let aspects: [Float] = [0.46, 1, 19.5 / 9, 2.2]
        for aspect in aspects {
            for heading in MotionTests.headings {
                let touching = pairFacing(heading, gap: scale.contact * 0.99, aspect: aspect)
                touching.tick()
                #expect(touching.census[.scissors] == 0)

                let apart = pairFacing(heading, gap: scale.contact * 1.01, aspect: aspect)
                apart.tick()
                #expect(apart.census[.scissors] == 1)
            }
        }
    }

    @Test func aStepIsTheSameLengthInEveryDirection() {
        let scale = Scale(soldiers: 100)
        let aspects: [Float] = [0.46, 1, 19.5 / 9, 2.2]
        for aspect in aspects {
            for heading in MotionTests.headings {
                let battle = pairFacing(heading, gap: scale.contact * 2, aspect: aspect)
                let before = battle.positionsNow[0]
                battle.tick()
                let stepped = battle.positionsNow[0] - before
                let length = (stepped.x * stepped.x + stepped.y * stepped.y).squareRoot()
                #expect(abs(length - scale.chaseStep) < 1e-5 * scale.contact)
                let along = (stepped.x * heading.x + stepped.y * heading.y) / max(length, 1e-20)
                #expect(along > 0.9999)
            }
        }
    }

    @Test func soldierIdentityIsStable() {
        let battle = Battle(Fixtures.setup(.even, soldiers: 300, seed: 15))
        let cap = battle.scale.displacementCap + Gate.coordinateRoundings * battle.coordinateUlp
        var previous = battle.positionsNow
        for _ in 0..<300 {
            battle.tick()
            let now = battle.positionsNow
            for i in 0..<now.count {
                let moved = now[i] - previous[i]
                #expect((moved.x * moved.x + moved.y * moved.y).squareRoot() <= cap)
            }
            previous = now
        }
    }

    @Test func aSoldierMovesAtTheSpeedTheRuleGivesIt() {
        let chase = chooser(prey: SIMD2(1.5, 0), predator: SIMD2(0, 3))
        let scale = chase.scale
        let middle = chase.arena * 0.5
        chase.tick()
        let stepped = chase.positionsNow[0] - middle
        #expect(abs((stepped.x * stepped.x + stepped.y * stepped.y).squareRoot() - scale.chaseStep) < 1e-6)
    }
}
