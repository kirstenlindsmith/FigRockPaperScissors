@_spi(Instrumentation) public struct Scale: Sendable {
    public let spacing: Float
    public let contact: Float
    public let body: Float
    public let chaseStep: Float
    public let fleeStep: Float
    public let displacementCap: Float
    public let interaction: Float

    public init(soldiers: Int) {
        let tuning = Tuning(soldiers: soldiers)
        spacing = tuning.spacing
        contact = tuning.contact
        body = tuning.body
        chaseStep = tuning.chaseStep
        fleeStep = tuning.fleeStep
        displacementCap = tuning.displacementCap
        interaction = tuning.interaction
    }
}

@_spi(Instrumentation) public struct Spacing: Sendable {
    public var mean: Float
    public var closest: Float
    public var withinHalfBody: Double
    public var withinBody: Double
    public var mixedNearest: Double
}

@_spi(Instrumentation) public struct SteeringSample: Sendable {
    public var soldier: Int
    public var position: SIMD2<Float>
    public var kind: Kind
    public var searchedPreyDistance: Float
    public var searchedPredatorDistance: Float
    public var coveredExactly: Float
    public var readEverything: Bool
    public var chasing: Bool
    public var hasTarget: Bool
    public var target: SIMD2<Float>
    public var targetDistance: Float
}

@_spi(Instrumentation) extension Battle {
    public static let tickDuration = Tuning.tick

    public var tickCount: Int { ticksRun }
    public var visits: Int { candidateVisits }
    public var worstVisitsForOneSoldier: Int { worstSoldierVisits }
    public var longestSearchedRow: Int { worstRowLength }
    public var cellCount: Int { cells }
    public var latticeSiteCount: Int { latticeSites }
    public var latticeSiteSpacing: SIMD2<Float> { latticeSpacing }

    public static let candidateCap = Tuning.candidateCap
    public static let exactReachRings = Tuning.exactReachRings
    public static let latticeSitesPerSoldierCeiling = Tuning.latticeSitesPerSoldierCeiling
    public static let constraintPasses = Tuning.constraintPasses
    public static let overlapPasses = Tuning.pushPasses

    public var scale: Scale { Scale(soldiers: soldiers) }

    public var coordinateUlp: Float { max(arena.x, arena.y).ulp }

    public convenience init(
        _ setup: Setup,
        rings: Int = Battle.exactReachRings,
        constraintPasses: Int = Battle.constraintPasses,
        overlapPasses: Int = Battle.overlapPasses,
        field: Bool = true,
        shuffledFill: Bool = true
    ) {
        self.init(
            setup,
            kernel: Kernel(
                exactReachRings: rings,
                constraintPasses: constraintPasses,
                pushPasses: overlapPasses,
                fieldEnabled: field,
                shuffledFill: shuffledFill
            )
        )
    }

    public convenience init(
        placing soldiers: [(SIMD2<Float>, Kind)],
        aspect: Float,
        constraintPasses: Int = Battle.constraintPasses,
        field: Bool = true
    ) {
        self.init(
            placing: soldiers,
            aspect: aspect,
            kernel: Kernel(constraintPasses: constraintPasses, fieldEnabled: field)
        )
    }

    public func digest() -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ value: UInt64) { hash = (hash ^ value) &* 0x1000_0000_1b3 }
        for i in 0..<soldiers {
            mix(UInt64(positions[i].x.bitPattern))
            mix(UInt64(positions[i].y.bitPattern))
            mix(UInt64(kinds[i].rawValue))
        }
        mix(UInt64(ticksRun))
        return hash
    }

    public func densestCell() -> Int {
        guard soldiers > 0 else { return 0 }
        bin()
        var most = 0
        for c in 0..<cells {
            let held = Int(cellStart[c + 1] - cellStart[c])
            if held > most { most = held }
        }
        return most
    }

    public func spacingNow() -> Spacing {
        let none = Spacing(mean: 0, closest: 0, withinHalfBody: 0, withinBody: 0, mixedNearest: 0)
        guard soldiers > 0 else { return none }
        bin()
        let body = tuning.body
        var sum = 0.0
        var closest = Float.infinity
        var half = 0
        var inside = 0
        var mixed = 0
        var measured = 0
        for slot in 0..<soldiers {
            let x = mirrorPosition[slot]
            let cell = Int(cellOf[Int(mirrorIndex[slot])])
            let ci = cell % gridWidth
            let cj = cell / gridWidth
            var best = Float.infinity
            var nearestKind = mirrorKind[slot]
            for bj in max(0, cj - 1)...min(gridHeight - 1, cj + 1) {
                let low = bj * gridWidth + max(0, ci - 1)
                let high = bj * gridWidth + min(gridWidth - 1, ci + 1)
                for j in Int(cellStart[low])..<Int(cellStart[high + 1]) where j != slot {
                    let d = squaredDistance(mirrorPosition[j], x)
                    if d < best {
                        best = d
                        nearestKind = mirrorKind[j]
                    }
                }
            }
            if best < .infinity {
                let d = best.squareRoot()
                sum += Double(d)
                measured += 1
                if d < closest { closest = d }
                if d < 0.5 * body { half += 1 }
                if d < body { inside += 1 }
                if nearestKind != mirrorKind[slot] { mixed += 1 }
            }
        }
        return Spacing(
            mean: measured > 0 ? Float(sum / Double(measured)) : 0,
            closest: closest == .infinity ? 0 : closest,
            withinHalfBody: Double(half) / Double(soldiers),
            withinBody: Double(inside) / Double(soldiers),
            mixedNearest: Double(mixed) / Double(max(1, measured))
        )
    }

    public func steeringSamples(stride: Int, rings: Int? = nil) -> [SteeringSample] {
        guard soldiers > 0 else { return [] }
        let depth = rings ?? kernel.exactReachRings
        bin()
        buildFields()
        var out: [SteeringSample] = []
        out.reserveCapacity(soldiers / max(1, stride) + 1)
        var slot = 0
        while slot < soldiers {
            let x = mirrorPosition[slot]
            let kind = mirrorKind[slot]
            let me = Int(mirrorIndex[slot])
            let found = scan(
                slot: slot,
                at: x,
                kind: kind,
                cell: Int(cellOf[me]),
                rings: depth,
                collect: false
            )
            let choice = decide(found, kind: kind, at: x)
            out.append(
                SteeringSample(
                    soldier: me,
                    position: x,
                    kind: kind,
                    searchedPreyDistance: found.preyDistance < .infinity
                        ? found.preyDistance.squareRoot() : .infinity,
                    searchedPredatorDistance: found.predatorDistance < .infinity
                        ? found.predatorDistance.squareRoot() : .infinity,
                    coveredExactly: found.coveredExactly,
                    readEverything: found.readEverything,
                    chasing: choice.chasing,
                    hasTarget: choice.hasTarget,
                    target: choice.target,
                    targetDistance: choice.hasTarget ? choice.targetDistance.squareRoot() : .infinity
                )
            )
            slot += stride
        }
        return out
    }
}
