import Glibc

@_spi(Instrumentation) import BattleEngine
@_spi(Instrumentation) import BattleFixtures

let arguments = Arguments(CommandLine.arguments)
let setup = makeSetup(arguments)
let budget = arguments.int("budget", 64 * 600)
let label =
    "n=\(setup.count) armies=\(arguments.text("armies", "even")) seed=\(setup.seed) "
    + "aspect=\(show(setup.aspect, 4))"

let searchRings = arguments.int("rings", Battle.exactReachRings)
let solvePasses = arguments.int("passes", Battle.constraintPasses)
let recoveryPasses = arguments.int("push", Battle.overlapPasses)
let farField = arguments.flag("field", true)
let shuffledFill = arguments.flag("fill", true)

func made(_ setup: Setup) -> Battle {
    Battle(
        setup,
        rings: searchRings,
        constraintPasses: solvePasses,
        overlapPasses: recoveryPasses,
        field: farField,
        shuffledFill: shuffledFill
    )
}

let kernelLabel =
    "rings=\(searchRings) passes=\(solvePasses) push=\(recoveryPasses) field=\(farField ? 1 : 0) "
    + "fill=\(shuffledFill ? 1 : 0)"

switch arguments.mode {

case "battle":
    let battle = made(setup)
    var watcher = Watcher(battle)
    let checked = arguments.flag("check", false)
    var previous = battle.withSoldiers { p, _ in Array(p) }
    var outOfBounds = 0
    var worstDisplacement: Float = 0
    var densest = 0
    let low = battle.scale.body * 0.5
    let high = battle.arenaSize - SIMD2(repeating: low)
    let started = nowNanoseconds()
    while !battle.census.isOver && battle.tickCount < budget {
        battle.advance(by: Battle.tickDuration)
        watcher.observe()
        if checked {
            battle.withSoldiers { now, _ in
                for i in 0..<now.count {
                    let p = now[i]
                    if !p.x.isFinite || !p.y.isFinite
                        || p.x < low || p.y < low || p.x > high.x || p.y > high.y {
                        outOfBounds += 1
                    }
                    let moved = p - previous[i]
                    let travelled = (moved.x * moved.x + moved.y * moved.y).squareRoot()
                    if travelled > worstDisplacement { worstDisplacement = travelled }
                    previous[i] = p
                }
            }
            densest = max(densest, battle.densestCell())
        }
    }
    let wall = nowNanoseconds() - started
    let census = battle.census
    var parts = [
        label,
        kernelLabel,
        "resolved=\(census.isOver)",
        "victor=" + (census.victor.map { String($0.rawValue) } ?? "-"),
        "ticks=\(battle.tickCount)",
        "seconds=" + show(Double(battle.tickCount) / 64, 2),
        "hands=" + show(watcher.handChangesPerSoldier, 3),
        "surges=\(watcher.surges)",
        "lifetime=" + show(watcher.meanKindLifetimeInSeconds, 3),
        "pops=\(census[.rock]),\(census[.paper]),\(census[.scissors])",
        "visits=" + show(Double(battle.visits) / Double(max(1, battle.tickCount * setup.count)), 2),
        "worstVisits=\(battle.worstVisitsForOneSoldier)",
        "longestRow=\(battle.longestSearchedRow)",
    ]
    if checked {
        parts += [
            "oob=\(outOfBounds)",
            "maxdisp=" + show(worstDisplacement / battle.scale.displacementCap, 7),
            "maxdispOverCapUlps="
                + show(
                    (worstDisplacement - battle.scale.displacementCap) / battle.arenaSize.x.ulp, 2
                ),
            "densest=\(densest)",
        ]
    }
    parts.append("wallSeconds=" + show(wall / 1e9, 2))
    report("BATTLE", parts)

case "bench":
    let battle = made(setup)
    let warm = arguments.int("warm", 30)
    let ticks = arguments.int("ticks", 120)
    let repeats = arguments.int("runs", 3)
    for _ in 0..<warm { battle.advance(by: Battle.tickDuration) }
    for run in 0..<repeats {
        let visitsBefore = battle.visits
        let started = nowNanoseconds()
        for _ in 0..<ticks { battle.advance(by: Battle.tickDuration) }
        let wall = nowNanoseconds() - started
        let census = battle.census
        report("BENCH", [
            label,
            kernelLabel,
            "run=\(run)",
            "msPerTick=" + show(wall / 1e6 / Double(ticks), 4),
            "ns=" + show(wall / Double(ticks * setup.count), 1),
            "visits=" + show(Double(battle.visits - visitsBefore) / Double(ticks * setup.count), 2),
            "hwmKB=\(highWaterKilobytes())",
            "storageKB=\(setup.storageBytes / 1024)",
            "pops=\(census[.rock]),\(census[.paper]),\(census[.scissors])",
        ])
    }

case "spacing":
    let battle = made(setup)
    let every = arguments.int("every", 100)
    var worstMean = Float.infinity
    var worstClosest = Float.infinity
    var worstHalf = 0.0
    var worstUnder = 0.0
    var meanOfMeans = 0.0
    var samples = 0
    var densest = 0
    let body = battle.scale.body
    let start = battle.spacingNow()
    while !battle.census.isOver && battle.tickCount < budget {
        battle.advance(by: Battle.tickDuration)
        densest = max(densest, battle.densestCell())
        if battle.tickCount % every == 0 {
            let now = battle.spacingNow()
            worstMean = min(worstMean, now.mean / body)
            worstClosest = min(worstClosest, now.closest / body)
            worstHalf = max(worstHalf, now.withinHalfBody)
            worstUnder = max(worstUnder, now.withinBody)
            meanOfMeans += Double(now.mean / body)
            samples += 1
        }
    }
    report("SPACING", [
        label,
        kernelLabel,
        "resolved=\(battle.census.isOver)",
        "ticks=\(battle.tickCount)",
        "samples=\(samples)",
        "startClosest=" + show(start.closest / body, 3),
        "startMixed=" + show(start.mixedNearest * 100, 1),
        "worstMeanNN=" + show(worstMean, 3),
        "worstClosest=" + show(worstClosest, 3),
        "meanNN=" + show(meanOfMeans / Double(max(1, samples)), 3),
        "maxWithinHalfBody=" + show(worstHalf * 100, 3),
        "maxWithinBody=" + show(worstUnder * 100, 3),
        "densest=\(densest)",
        "longestRow=\(battle.longestSearchedRow)",
        "worstVisits=\(battle.worstVisitsForOneSoldier)",
    ])

case "steering":
    let battle = made(setup)
    let instants = arguments.list("at").isEmpty ? [64, 256, 1024, 4096] : arguments.list("at")
    let stride = arguments.int("stride", 37)
    for instant in instants {
        while battle.tickCount < instant && !battle.census.isOver {
            battle.advance(by: Battle.tickDuration)
        }
        report(
            "STEERING",
            [label, kernelLabel, "t=\(battle.tickCount)", steeringReport(battle, stride: stride, rings: nil)]
        )
    }

case "rings":
    let battle = made(setup)
    let instants = arguments.list("at").isEmpty ? [64, 1024] : arguments.list("at")
    let stride = arguments.int("stride", 37)
    let depths = arguments.list("depths").isEmpty ? [1, 2, 3, 4, 6] : arguments.list("depths")
    for instant in instants {
        while battle.tickCount < instant && !battle.census.isOver {
            battle.advance(by: Battle.tickDuration)
        }
        for depth in depths {
            report(
                "RINGS",
                [
                    label, "t=\(battle.tickCount)", "rings=\(depth)",
                    steeringReport(battle, stride: stride, rings: depth),
                ]
            )
        }
    }

case "geometry":
    let placementStarted = nowNanoseconds()
    let battle = made(setup)
    let placementMs = (nowNanoseconds() - placementStarted) / 1e6
    let spacing = battle.spacingNow()
    let coverage = Coverage(battle)
    let scale = battle.scale
    let arena = battle.arenaSize
    report("GEOMETRY", [
        label,
        kernelLabel,
        "W=" + show(arena.x, 5),
        "H=" + show(arena.y, 5),
        "area=" + show(arena.x * arena.y, 5),
        "widthInBodies=" + show(arena.x / scale.body, 1),
        "heightInBodies=" + show(arena.y / scale.body, 1),
        "sitesPerSoldier=" + show(Double(battle.latticeSiteCount) / Double(max(1, setup.count)), 3),
        "siteSpacingInBodies="
            + show(min(battle.latticeSiteSpacing.x, battle.latticeSiteSpacing.y) / scale.body, 3),
        "cellsPerSoldier=" + show(Double(battle.cellCount) / Double(max(1, setup.count)), 3),
        "closestPair=" + show(spacing.closest / scale.body, 4),
        "meanNN=" + show(spacing.mean / scale.body, 3),
        "withinBody=" + show(spacing.withinBody * 100, 4),
        "mixedNearest=" + show(spacing.mixedNearest * 100, 1),
        "blocks=\(coverage.across)x\(coverage.down)",
        "perBlock=" + show(coverage.expected, 1),
        "emptyBlocks=\(coverage.emptyBlocks)",
        "worstBlock=" + show(coverage.worstBlockNoises, 2),
        "initMs=" + show(placementMs, 2),
        "storageKB=\(setup.storageBytes / 1024)",
        "pops=\(battle.census[.rock]),\(battle.census[.paper]),\(battle.census[.scissors])",
    ])

case "invariance":
    let ticks = arguments.int("ticks", 400)
    let whole = made(setup)
    whole.advance(by: Battle.tickDuration * ticks)
    let reference = whole.digest()
    var agree = true
    var state = setup.seed &* 6_364_136_223_846_793_005 &+ 1
    func nextRandom() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state >> 11
    }
    for trial in 0..<8 {
        let part = made(setup)
        var left = Battle.tickDuration * ticks
        while left > .zero {
            var chunk: Duration
            switch trial {
            case 0: chunk = Battle.tickDuration
            case 1: chunk = nextRandom() % 2 == 0 ? .zero : Battle.tickDuration * 3
            case 2:
                chunk = Duration(
                    secondsComponent: 0,
                    attosecondsComponent: Int64(nextRandom() % 2_232_142_857_142_857)
                )
            default:
                chunk = Duration(
                    secondsComponent: 0,
                    attosecondsComponent: Int64(nextRandom() % 78_125_000_000_000_000)
                )
            }
            if chunk > left { chunk = left }
            if chunk == .zero {
                part.advance(by: .zero)
                continue
            }
            part.advance(by: chunk)
            left -= chunk
        }
        if part.digest() != reference || part.tickCount != whole.tickCount {
            agree = false
            print("MISMATCH trial=\(trial) ticks=\(part.tickCount) want=\(whole.tickCount)")
        }
    }
    let again = made(setup)
    again.advance(by: .seconds(-10))
    again.advance(by: Battle.tickDuration * ticks)
    if again.digest() != reference {
        agree = false
        print("MISMATCH negative")
    }
    report("INVARIANCE", [
        label,
        kernelLabel,
        "agree=\(agree)",
        "ticks=\(whole.tickCount)",
        "digest=" + String(reference, radix: 16),
    ])

default:
    print("modes: battle bench spacing steering rings geometry invariance")
}
