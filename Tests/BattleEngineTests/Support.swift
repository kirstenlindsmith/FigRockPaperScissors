import BattleFixtures

@_spi(Instrumentation) import BattleEngine

extension Battle {
    func tick() { advance(by: Battle.tickDuration) }

    func run(ticks: Int, watching: (Battle) -> Void = { _ in }) {
        for _ in 0..<ticks {
            tick()
            watching(self)
        }
    }

    func runToEnd(within ticks: Int, watching: (Battle) -> Void = { _ in }) -> Bool {
        var left = ticks
        while !census.isOver && left > 0 {
            tick()
            watching(self)
            left -= 1
        }
        return census.isOver
    }

    var positionsNow: [SIMD2<Float>] { withSoldiers { p, _ in Array(p) } }
    var kindsNow: [Kind] { withSoldiers { _, k in Array(k) } }

    var insetLow: SIMD2<Float> { SIMD2(repeating: scale.body * 0.5) }
    var insetHigh: SIMD2<Float> { arena - insetLow }
}

let screens: [Float] = [0.36, 0.46, 1, 19.5 / 9, 32, 1e-30, 1e30]

func wins(soldiers: Int, seeds: Int, shuffledFill: Bool = true) -> [Int] {
    var wins = [0, 0, 0]
    for seed in UInt64(1)...UInt64(seeds) {
        let battle = Battle(
            Fixtures.setup(.even, soldiers: soldiers, seed: seed),
            shuffledFill: shuffledFill
        )
        _ = battle.runToEnd(within: Gate.resolutionTicks(soldiers: soldiers))
        if let victor = battle.census.victor { wins[Int(victor.rawValue)] += 1 }
    }
    return wins
}

func hand(
    _ soldiers: [(SIMD2<Float>, Kind)],
    aspect: Float = Fixtures.phoneAspect
) -> Battle {
    Battle(placing: soldiers, aspect: aspect)
}

func clumped(_ flock: Int, apart step: Float, around centre: SIMD2<Float>) -> [SIMD2<Float>] {
    let columns = max(1, Int(Float(flock).squareRoot().rounded(.up)))
    let rows = (flock + columns - 1) / columns
    let corner = centre - SIMD2(Float(columns - 1) * step, Float(rows - 1) * step) * 0.5
    return (0..<flock).map {
        corner + SIMD2(Float($0 % columns) * step, Float($0 / columns) * step)
    }
}

func hunterSeeing(_ crowd: Int, spacingsAway away: Float, field: Bool = true) -> Battle {
    let soldiers = crowd + 1
    let scale = Scale(soldiers: soldiers)
    let arena = Fixtures.setup(.even, soldiers: soldiers, seed: 1).arena
    let centre = SIMD2<Float>(arena.x * 0.25, arena.y * 0.5)
    var placing = clumped(crowd, apart: 0.5 * scale.spacing, around: centre).map { ($0, Kind.rock) }
    placing.append((centre + SIMD2(away * scale.spacing, 0), .paper))
    return Battle(placing: placing, aspect: Fixtures.phoneAspect, field: field)
}

func pile(flock: Int, intruderAt intruder: Int) -> Battle {
    let scale = Scale(soldiers: flock)
    let arena = Fixtures.setup(.even, soldiers: flock, seed: 1).arena
    let spots = clumped(flock, apart: 0.05 * scale.spacing, around: arena * 0.5)
    return hand(spots.enumerated().map { ($0.element, $0.offset == intruder ? .paper : .rock) })
}

func pileSeenFrom(spacingsAway away: Float, flock: Int) -> Battle {
    let scale = Scale(soldiers: flock + 1)
    let arena = Fixtures.setup(.even, soldiers: flock + 1, seed: 1).arena
    let spots = clumped(flock, apart: 0.005 * scale.spacing, around: arena * 0.5)
    var placing = spots.map { ($0, Kind.rock) }
    placing.append((arena * 0.5 + SIMD2(away * scale.spacing, 0), .paper))
    return hand(placing)
}

func arena(soldiers: Int, aspect: Float) -> SIMD2<Float> {
    Fixtures.setup(.even, soldiers: soldiers, seed: 1, aspect: aspect).arena
}

func pileOnAPoint(_ soldiers: Int, aspect: Float = Fixtures.phoneAspect)
    -> [(SIMD2<Float>, Kind)]
{
    let middle = arena(soldiers: soldiers, aspect: aspect) * 0.5
    return (0..<soldiers).map { (middle, Kind.allCases[$0 % 3]) }
}

func pileInACorner(_ soldiers: Int) -> [(SIMD2<Float>, Kind)] {
    (0..<soldiers).map { (SIMD2<Float>.zero, Kind.allCases[$0 % 3]) }
}

func wildField(aspect: Float = Fixtures.phoneAspect) -> [(SIMD2<Float>, Kind)] {
    let arena = arena(soldiers: 14, aspect: aspect)
    let spots: [SIMD2<Float>] = [
        SIMD2(.nan, .nan),
        SIMD2(.infinity, .infinity),
        SIMD2(-.infinity, -.infinity),
        SIMD2(.nan, arena.y * 0.5),
        SIMD2(arena.x * 0.5, -.infinity),
        SIMD2(1e30, 1e30),
        SIMD2(-1e30, 1e-30),
        SIMD2(1e10, 1e10),
        SIMD2(-1, -1),
        SIMD2(arena.x * 3, arena.y * 0.5),
        .zero,
        arena,
        SIMD2(-0.0, 0.0),
        arena * 0.5,
    ]
    return spots.enumerated().map { ($0.element, Kind.allCases[$0.offset % 3]) }
}

func chooser(prey: SIMD2<Float>, predator: SIMD2<Float>) -> Battle {
    let soldiers = 200
    let scale = Scale(soldiers: soldiers)
    let middle = arena(soldiers: soldiers, aspect: Fixtures.phoneAspect) * 0.5
    var placing: [(SIMD2<Float>, Kind)] = [
        (middle, .rock),
        (middle + prey * scale.spacing, .scissors),
        (middle + predator * scale.spacing, .paper),
    ]
    for _ in 3..<soldiers { placing.append((SIMD2(repeating: scale.body), .rock)) }
    return hand(placing)
}

func pairFacing(
    _ heading: SIMD2<Float>,
    gap: Float,
    aspect: Float,
    bystanders: Int = 98
) -> Battle {
    let soldiers = 2 + bystanders
    let scale = Scale(soldiers: soldiers)
    let arena = Fixtures.setup(.even, soldiers: soldiers, seed: 1, aspect: aspect).arena
    let middle = arena * 0.5
    var placing: [(SIMD2<Float>, Kind)] = [
        (middle, .rock),
        (middle + heading * gap, .scissors),
    ]
    let corner = SIMD2<Float>(scale.body, scale.body)
    for _ in 0..<bystanders { placing.append((corner, .paper)) }
    return hand(placing, aspect: aspect)
}

func spread(_ battle: Battle) -> Float {
    let positions = battle.positionsNow
    var closest = Float.infinity
    for i in 0..<positions.count {
        for j in (i + 1)..<positions.count {
            let delta = positions[i] - positions[j]
            closest = min(closest, (delta.x * delta.x + delta.y * delta.y).squareRoot())
        }
    }
    return closest
}
