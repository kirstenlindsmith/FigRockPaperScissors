import Testing

@_spi(Instrumentation) import BattleEngine
@_spi(Instrumentation) import BattleFixtures

@Suite struct SearchTests {
    static let instants = [16, 64, 256, 1024]

    @Test(arguments: Armies.allCases)
    func theTargetIsTheNearestWhereItCanBeSeenToBe(armies: Armies) {
        let battle = Battle(Fixtures.setup(armies, soldiers: 600, seed: 1))
        var checkedInsideReach = 0
        for instant in SearchTests.instants {
            while battle.tickCount < instant && !battle.census.isOver { battle.tick() }
            let audit = battle.auditSearch(stride: 5)
            #expect(audit.blinded == 0)
            #expect(audit.identityBroken == 0)
            #expect(audit.worstTargetRatio <= Gate.targetDistanceOverNearest)
            #expect(audit.widestDecidingTie <= Gate.decidingTie)
            checkedInsideReach += audit.nearestInsideReach
        }
        #expect(checkedInsideReach > 0)
    }

    @Test func aShallowerSearchIsMeasurablyWorseWhereTheArmiesMix() {
        let battle = Battle(Fixtures.setup(.even, soldiers: 600, seed: 1))
        var deepest = 1.0
        var shallow = 1.0
        for instant in SearchTests.instants {
            while battle.tickCount < instant && !battle.census.isOver { battle.tick() }
            deepest = max(deepest, battle.auditSearch(stride: 5).worstTargetRatio)
            let shallower = battle.auditSearch(stride: 5, rings: 1)
            #expect(shallower.identityBroken == 0)
            shallow = max(shallow, shallower.worstTargetRatio)
        }
        #expect(deepest <= Gate.targetDistanceOverNearest)
        #expect(shallow > deepest * Gate.shallowSearchPenalty)
    }

    @Test(arguments: Armies.allCases)
    func theCandidateCapNeverBindsInABattle(armies: Armies) {
        let battle = Battle(Fixtures.setup(armies, soldiers: 600, seed: 2))
        _ = battle.runToEnd(within: Gate.resolutionTicks(soldiers: 600))
        #expect(battle.longestSearchedRow <= Battle.candidateCap)
        #expect(battle.worstVisitsForOneSoldier <= Gate.visitsForOneSoldier)
    }

    @Test func theWorkPerSoldierDoesNotGrowWithTheArmy() {
        var perSoldier: [Double] = []
        for soldiers in [Gate.smallestSizeForVisitGrowth, 8 * Gate.smallestSizeForVisitGrowth] {
            let battle = Battle(Fixtures.setup(.even, soldiers: soldiers, seed: 1))
            battle.run(ticks: 40)
            #expect(battle.worstVisitsForOneSoldier <= Gate.visitsForOneSoldier)
            #expect(battle.visits <= Gate.visitsForOneSoldier * soldiers * battle.tickCount)
            perSoldier.append(Double(battle.visits) / Double(soldiers * battle.tickCount))
        }
        #expect(perSoldier[1] / perSoldier[0] < Gate.visitsPerSoldierGrowth)
        #expect(perSoldier[0] > 0)
    }

    @Test(arguments: [200, 800])
    func aPileCostsNoMoreToSearchThanACrowd(flock: Int) {
        let battle = pile(flock: flock, intruderAt: flock - 50)
        battle.tick()
        #expect(battle.longestSearchedRow > Battle.candidateCap)
        #expect(battle.worstVisitsForOneSoldier <= Gate.visitsForOneSoldier)
        #expect(Double(battle.visits) / Double(flock) <= Double(Gate.visitsForOneSoldier))
    }

    @Test func theFarFieldFindsPreyBeyondTheSearchReach() {
        let seeing = hunterSeeing(599, spacingsAway: 20)
        var ticks = 0
        while seeing.census[.paper] == 1 && ticks < 1_000 {
            seeing.tick()
            ticks += 1
        }
        #expect(seeing.census[.paper] > 1)
        let blind = hunterSeeing(599, spacingsAway: 20, field: false)
        blind.run(ticks: 1_000)
        #expect(blind.census[.paper] == 1)
    }

    @Test func aCrowdSeenFromOutsideItsOwnGroundCostsNoMoreThanTheBound() {
        let battle = pileSeenFrom(spacingsAway: 3, flock: 800)
        let watcher = try! #require(battle.steeringSamples(stride: 1).first { $0.kind == .paper })
        #expect(watcher.readEverything)
        #expect(watcher.searchedPreyDistance.isFinite)
        #expect(battle.densestCell() > Gate.visitsForOneSoldier)
        battle.tick()
        #expect(battle.worstVisitsForOneSoldier <= Gate.visitsForOneSoldier)
    }

    @Test func nowhereInACrowdTooDenseToReadAtOnceIsAPlaceToHide() {
        let flock = 200
        for intruder in stride(from: 0, to: flock, by: 17) {
            let battle = pile(flock: flock, intruderAt: intruder)
            battle.tick()
            #expect(battle.longestSearchedRow > Battle.candidateCap)
            #expect(battle.runToEnd(within: Gate.resolutionTicks(soldiers: flock)))
            #expect(battle.census.victor == .paper)
        }
    }

    @Test func aCrowdTooDenseToReadAtOnceIsReportedRatherThanAudited() {
        let battle = pile(flock: 200, intruderAt: 100)
        battle.tick()
        let audit = battle.auditSearch(stride: 1)
        #expect(battle.longestSearchedRow > Battle.candidateCap)
        #expect(audit.samples > 0)
        #expect(audit.blinded == audit.samples)
        #expect(audit.nearestInsideReach == 0)
    }

    @Test(arguments: Armies.allCases)
    func theTargetASoldierStepsTowardIsTheNearestItShouldSteerAt(armies: Armies) {
        let soldiers = 600
        let scale = Scale(soldiers: soldiers)
        let battle = Battle(Fixtures.setup(armies, soldiers: soldiers, seed: 4))
        var judged = 0
        var exact = 0
        for instant in [32, 128, 512] {
            while battle.tickCount < instant && !battle.census.isOver { battle.tick() }
            let before = battle.positionsNow
            let kinds = battle.kindsNow
            let low = battle.insetLow
            let high = battle.insetHigh
            battle.tick()
            let after = battle.positionsNow
            for i in 0..<soldiers where after[i] != before[i] {
                let walls = min(
                    min(before[i].x - low.x, high.x - before[i].x),
                    min(before[i].y - low.y, high.y - before[i].y)
                )
                guard walls > scale.displacementCap else { continue }
                guard Steering.crowding(around: i, in: before) > scale.interaction else { continue }
                let step = after[i] - before[i]
                let length = (step.x * step.x + step.y * step.y).squareRoot()
                let chasing = abs(length - scale.chaseStep) < 1e-4 * scale.chaseStep
                let fleeing = abs(length - scale.fleeStep) < 1e-4 * scale.chaseStep
                #expect(chasing || fleeing)
                guard chasing || fleeing else { continue }
                let wanted = chasing ? kinds[i].beats : kinds[i].beats.beats
                let heading = chasing ? step / length : -step / length
                let aimed = Steering.nearest(
                    of: wanted, from: before[i], along: heading, in: before, kinds: kinds
                )
                let truth = Steering.nearest(of: wanted, from: before[i], in: before, kinds: kinds)
                let aimedAt = try! #require(aimed)
                let nearest = try! #require(truth)
                judged += 1
                if aimedAt <= nearest * (1 + 1e-5) { exact += 1 }
                #expect(Double(aimedAt / nearest) <= Gate.targetDistanceOverNearest)
            }
        }
        #expect(judged > 0)
        #expect(
            Double(exact) / Double(judged) >= Gate.unconstrainedSoldiersSteeringAtTheTrueNearest
        )
    }
}

enum Steering {
    static func crowding(around i: Int, in positions: [SIMD2<Float>]) -> Float {
        var closest = Float.infinity
        for j in 0..<positions.count where j != i {
            let delta = positions[j] - positions[i]
            closest = min(closest, delta.x * delta.x + delta.y * delta.y)
        }
        return closest.squareRoot()
    }

    static func nearest(
        of kind: Kind,
        from x: SIMD2<Float>,
        in positions: [SIMD2<Float>],
        kinds: [Kind]
    ) -> Float? {
        var best = Float.infinity
        for j in 0..<positions.count where kinds[j] == kind {
            let delta = positions[j] - x
            let d = delta.x * delta.x + delta.y * delta.y
            if d > 0 && d < best { best = d }
        }
        return best == .infinity ? nil : best.squareRoot()
    }

    static func nearest(
        of kind: Kind,
        from x: SIMD2<Float>,
        along heading: SIMD2<Float>,
        in positions: [SIMD2<Float>],
        kinds: [Kind]
    ) -> Float? {
        var best = Float.infinity
        for j in 0..<positions.count where kinds[j] == kind {
            let delta = positions[j] - x
            let d = (delta.x * delta.x + delta.y * delta.y).squareRoot()
            guard d > 0 else { continue }
            let cosine = (delta.x * heading.x + delta.y * heading.y) / d
            if cosine > 0.9999 && d < best { best = d }
        }
        return best == .infinity ? nil : best
    }
}
