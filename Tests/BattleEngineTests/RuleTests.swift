import BattleFixtures
import Testing

@_spi(Instrumentation) import BattleEngine

@Suite struct RuleTests {
    static let pairs: [(Kind, Kind)] = [(.rock, .scissors), (.paper, .rock), (.scissors, .paper)]

    @Test(arguments: pairs)
    func contactConvertsTheLoserIntoTheWinner(winner: Kind, loser: Kind) {
        let scale = Scale(soldiers: 2)
        let middle = SIMD2<Float>(0.6, 0.34)
        let battle = hand([
            (middle, winner),
            (middle + SIMD2(scale.contact * 0.9, 0), loser),
        ])
        #expect(battle.census[loser] == 1)
        battle.tick()
        #expect(battle.census[winner] == 2)
        #expect(battle.census[loser] == 0)
        #expect(battle.census.victor == winner)
    }

    @Test func aTouchConvertsAndAGapDoesNot() {
        let contact = Scale(soldiers: 2).contact
        let middle = SIMD2<Float>(0.6, 0.34)
        let touching = hand([(middle, .rock), (middle + SIMD2(contact * 0.99, 0), .scissors)])
        touching.tick()
        #expect(touching.census[.rock] == 2)

        let apart = hand([(middle, .rock), (middle + SIMD2(contact * 1.01, 0), .scissors)])
        apart.tick()
        #expect(apart.census[.rock] == 1)
        #expect(apart.census[.scissors] == 1)
    }

    @Test func aSoldierPulledEquallyChases() {
        let scale = Scale(soldiers: 3)
        let middle = SIMD2<Float>(0.7, 0.34)
        let reach = 2 * scale.spacing
        let battle = hand([
            (middle, .rock),
            (middle + SIMD2(reach, 0), .scissors),
            (middle - SIMD2(reach, 0), .paper),
        ])
        battle.tick()
        let moved = battle.positionsNow[0] - middle
        #expect(moved.x > 0)
        #expect(abs(moved.y) < 1e-6)
        #expect(abs(moved.x - scale.chaseStep) < 1e-6)
    }

    @Test func aSoldierFleesWhatIsNearerThanItsPrey() {
        let scale = Scale(soldiers: 3)
        let middle = SIMD2<Float>(0.7, 0.34)
        let battle = hand([
            (middle, .rock),
            (middle + SIMD2(2.4 * scale.spacing, 0), .scissors),
            (middle - SIMD2(2 * scale.spacing, 0), .paper),
        ])
        battle.tick()
        let moved = battle.positionsNow[0] - middle
        #expect(moved.x > 0)
        #expect(abs(moved.x - scale.fleeStep) < 1e-6)
    }

    @Test func aQuarryWithNowhereToGoIsCaughtRatherThanPassedThrough() {
        let scale = Scale(soldiers: 2)
        let gaps: [Float] = [1.01, 1.2, 1.5, 2.0, 1 + 2 * 2.4 * 0.25]
        for factor in gaps {
            let gap = scale.contact * factor
            let quarry = SIMD2<Float>(scale.body * 0.5, 0.353)
            let chaser = quarry + SIMD2(gap, 0)
            let battle = hand([(chaser, .rock), (quarry, .scissors)], aspect: 2)
            var caught = false
            for _ in 0..<14 {
                battle.tick()
                if battle.census[.scissors] == 0 {
                    caught = true
                    break
                }
                let now = battle.positionsNow
                #expect(now[0].x > now[1].x)
                let gapNow = now[0] - now[1]
                #expect((gapNow.x * gapNow.x + gapNow.y * gapNow.y).squareRoot() >= scale.body * 0.99)
            }
            #expect(caught)
        }
    }

    @Test func twoSoldiersOnOnePointComeApartAndStayApart() {
        let scale = Scale(soldiers: 4)
        let point = SIMD2<Float>(0.7, 0.34)
        let battle = hand([
            (point, .rock),
            (point, .rock),
            (point + SIMD2(0.5, 0.2), .paper),
            (point + SIMD2(0.6, 0.25), .scissors),
        ])
        #expect(spread(battle) == 0)
        for _ in 0..<40 {
            battle.tick()
            let positions = battle.positionsNow
            let gap = positions[0] - positions[1]
            let apart = (gap.x * gap.x + gap.y * gap.y).squareRoot()
            #expect(apart > 0)
            #expect(positions[0].x.isFinite && positions[1].y.isFinite)
            if battle.census.isOver { break }
        }
        let positions = battle.positionsNow
        let gap = positions[0] - positions[1]
        #expect((gap.x * gap.x + gap.y * gap.y).squareRoot() >= scale.body * 0.5)
    }

    @Test func nothingOutsideTheSearchedGroundEntersTheDecision() {
        let soldiers = 6
        let scale = Scale(soldiers: soldiers)
        let subject = SIMD2<Float>(0.5, 0.34)
        func battle(withDistantFriendAt spot: SIMD2<Float>) -> Battle {
            hand([
                (subject, .rock),
                (subject + SIMD2(1.1 * scale.spacing, 0.2 * scale.spacing), .scissors),
                (subject + SIMD2(-0.9 * scale.spacing, 0.4 * scale.spacing), .paper),
                (spot, .rock),
                (SIMD2(1.35, 0.62), .paper),
                (SIMD2(1.3, 0.05), .scissors),
            ])
        }
        let near = battle(withDistantFriendAt: SIMD2(0.05, 0.62))
        let far = battle(withDistantFriendAt: SIMD2(0.09, 0.05))
        near.tick()
        far.tick()
        #expect(near.positionsNow[0] == far.positionsNow[0])
        #expect(near.kindsNow[0] == far.kindsNow[0])
    }

    @Test func theCycleIsClosedAndNoKindIsSpecial() {
        for kind in Kind.allCases {
            #expect(kind.beats != kind)
            #expect(kind.beats.beats != kind)
            #expect(kind.beats.beats.beats == kind)
        }
        #expect(Kind.rock.beats == .scissors)
        #expect(Kind.paper.beats == .rock)
        #expect(Kind.scissors.beats == .paper)
    }

    @Test func extinctionIsOneWay() {
        for seed in UInt64(1)...6 {
            let battle = Battle(Fixtures.setup(.even, soldiers: 60, seed: seed))
            var dead: Set<Kind> = []
            while !battle.census.isOver && battle.tickCount < 20_000 {
                battle.tick()
                let census = battle.census
                for kind in Kind.allCases {
                    if census[kind] == 0 { dead.insert(kind) }
                    if dead.contains(kind) { #expect(census[kind] == 0) }
                }
            }
            #expect(battle.census.isOver)
        }
    }
}
