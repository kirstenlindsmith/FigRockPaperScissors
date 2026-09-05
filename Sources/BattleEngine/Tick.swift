extension Battle {
    @inline(__always)
    func cellIndex(_ p: SIMD2<Float>) -> Int {
        var i = Int(p.x / cellSize.x)
        var j = Int(p.y / cellSize.y)
        if i < 0 { i = 0 }
        if i >= gridWidth { i = gridWidth - 1 }
        if j < 0 { j = 0 }
        if j >= gridHeight { j = gridHeight - 1 }
        return j * gridWidth + i
    }

    func bin() {
        for c in 0...cells {
            cellStart[c] = 0
            cellKinds[c] = 0
        }
        for i in 0..<soldiers {
            let c = cellIndex(positions[i])
            cellOf[i] = Int32(c)
            cellStart[c + 1] += 1
            cellKinds[c] |= UInt8(1) << kinds[i].rawValue
        }
        var running: Int32 = 0
        for c in 0...cells {
            running += cellStart[c]
            cellStart[c] = running
            cellCursor[c] = running
        }
        for i in 0..<soldiers {
            let c = Int(cellOf[i])
            let slot = Int(cellCursor[c])
            cellCursor[c] = Int32(slot + 1)
            mirrorPosition[slot] = positions[i]
            mirrorKind[slot] = kinds[i]
            mirrorIndex[slot] = Int32(i)
        }
    }

    func buildFields() {
        let empty = SIMD2<Float>(repeating: .infinity)
        for i in 0..<3 * fieldCells {
            fieldPosition[i] = empty
            fieldSeedDistance[i] = .infinity
        }
        for i in 0..<soldiers {
            let p = positions[i]
            var fi = Int(p.x / fieldCellSize.x)
            var fj = Int(p.y / fieldCellSize.y)
            if fi < 0 { fi = 0 }
            if fi >= fieldWidth { fi = fieldWidth - 1 }
            if fj < 0 { fj = 0 }
            if fj >= fieldHeight { fj = fieldHeight - 1 }
            let slot = kinds[i].index * fieldCells + fj * fieldWidth + fi
            let centre = SIMD2<Float>(
                (Float(fi) + 0.5) * fieldCellSize.x,
                (Float(fj) + 0.5) * fieldCellSize.y
            )
            let e = p - centre
            let d = e.x * e.x + e.y * e.y
            if d < fieldSeedDistance[slot] {
                fieldSeedDistance[slot] = d
                fieldPosition[slot] = p
            }
        }
        for k in 0..<3 {
            let base = k * fieldCells
            for j in 0..<fieldHeight {
                let cy = (Float(j) + 0.5) * fieldCellSize.y
                for i in 0..<fieldWidth {
                    let here = base + j * fieldWidth + i
                    let centre = SIMD2<Float>((Float(i) + 0.5) * fieldCellSize.x, cy)
                    var best = fieldPosition[here]
                    var bestDistance = best.x == .infinity ? Float.infinity : squaredDistance(best, centre)
                    if i > 0 { consider(here - 1, centre, &best, &bestDistance) }
                    if j > 0 {
                        consider(here - fieldWidth, centre, &best, &bestDistance)
                        if i > 0 { consider(here - fieldWidth - 1, centre, &best, &bestDistance) }
                        if i < fieldWidth - 1 { consider(here - fieldWidth + 1, centre, &best, &bestDistance) }
                    }
                    fieldPosition[here] = best
                }
            }
            for j in stride(from: fieldHeight - 1, through: 0, by: -1) {
                let cy = (Float(j) + 0.5) * fieldCellSize.y
                for i in stride(from: fieldWidth - 1, through: 0, by: -1) {
                    let here = base + j * fieldWidth + i
                    let centre = SIMD2<Float>((Float(i) + 0.5) * fieldCellSize.x, cy)
                    var best = fieldPosition[here]
                    var bestDistance = best.x == .infinity ? Float.infinity : squaredDistance(best, centre)
                    if i < fieldWidth - 1 { consider(here + 1, centre, &best, &bestDistance) }
                    if j < fieldHeight - 1 {
                        consider(here + fieldWidth, centre, &best, &bestDistance)
                        if i < fieldWidth - 1 { consider(here + fieldWidth + 1, centre, &best, &bestDistance) }
                        if i > 0 { consider(here + fieldWidth - 1, centre, &best, &bestDistance) }
                    }
                    fieldPosition[here] = best
                }
            }
        }
    }

    @inline(__always)
    private func consider(
        _ slot: Int,
        _ centre: SIMD2<Float>,
        _ best: inout SIMD2<Float>,
        _ bestDistance: inout Float
    ) {
        let candidate = fieldPosition[slot]
        if candidate.x == .infinity { return }
        let d = squaredDistance(candidate, centre)
        if d < bestDistance {
            bestDistance = d
            best = candidate
        }
    }

    @inline(__always)
    func squaredDistance(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let e = a - b
        return e.x * e.x + e.y * e.y
    }

    struct Scan {
        var preyDistance: Float = .infinity
        var prey: SIMD2<Float> = .zero
        var predatorDistance: Float = .infinity
        var predator: SIMD2<Float> = .zero
        var predatorIndex: Int32 = -1
        var neighbours = 0
        var overlapping = false
        var visits = 0
        var coveredExactly: Float = 0
        var longestRow = 0
        var readEverything = true
    }

    struct Decision {
        var chasing = false
        var hasTarget = false
        var target = SIMD2<Float>.zero
        var targetDistance = Float.infinity
        var preyDistance = Float.infinity
        var predatorDistance = Float.infinity
    }

    @inline(__always)
    func decide(_ found: Scan, kind: Kind, at x: SIMD2<Float>) -> Decision {
        var prey = found.prey
        var predator = found.predator
        var preyDistance = found.preyDistance
        var predatorDistance = found.predatorDistance
        if kernel.fieldEnabled {
            if preyDistance == .infinity, let far = fieldTarget(kind.beats, at: x) {
                prey = far
                preyDistance = squaredDistance(far, x)
            }
            if predatorDistance == .infinity, let far = fieldTarget(kind.beatenBy, at: x) {
                predator = far
                predatorDistance = squaredDistance(far, x)
            }
        }
        var out = Decision()
        out.chasing = preyDistance < .infinity && preyDistance <= predatorDistance
        out.hasTarget = preyDistance < .infinity || predatorDistance < .infinity
        out.target = out.chasing ? prey : predator
        out.targetDistance = out.chasing ? preyDistance : predatorDistance
        out.preyDistance = preyDistance
        out.predatorDistance = predatorDistance
        return out
    }

    @inline(__always)
    func scan(
        slot: Int,
        at x: SIMD2<Float>,
        kind: Kind,
        cell: Int,
        rings: Int,
        collect: Bool
    ) -> Scan {
        var out = Scan()
        let preyKind = kind.beats
        let predatorKind = kind.beatenBy
        let ci = cell % gridWidth
        let cj = cell / gridWidth
        let cap = Tuning.candidateCap
        let reach = tuning.interaction
        let body = tuning.body
        let span = Tuning.firstRingRows / 2

        for bj in max(0, cj - span)...min(gridHeight - 1, cj + span) {
            let low = bj * gridWidth + max(0, ci - span)
            let high = bj * gridWidth + min(gridWidth - 1, ci + span)
            let first = Int(cellStart[low])
            let end = Int(cellStart[high + 1])
            let length = end - first
            if length == 0 { continue }
            if length > out.longestRow { out.longestRow = length }
            if length > cap { out.readEverything = false }
            let take = min(length, cap)
            var j = first
            if length > cap {
                j = first + (ticksRun &* cap) % length
                if j >= end { j -= length }
            }
            out.visits += take
            for _ in 0..<take {
                if j != slot {
                    let other = mirrorPosition[j]
                    let delta = other - x
                    let d2 = delta.x * delta.x + delta.y * delta.y
                    let k = mirrorKind[j]
                    if k == preyKind {
                        if d2 < out.preyDistance {
                            out.preyDistance = d2
                            out.prey = other
                        }
                    } else if k == predatorKind {
                        if d2 < out.predatorDistance {
                            out.predatorDistance = d2
                            out.predator = other
                            out.predatorIndex = mirrorIndex[j]
                        }
                    }
                    if collect && d2 < reach * reach {
                        let n = out.neighbours
                        if d2 < Tuning.coincidenceSquared {
                            let u = pairDirection(Int(mirrorIndex[slot]), Int(mirrorIndex[j]))
                            neighbourDelta[n] = -u * body
                            neighbourDistance[n] = 0
                        } else {
                            neighbourDelta[n] = delta
                            neighbourDistance[n] = d2.squareRoot()
                        }
                        neighbourIndex[n] = mirrorIndex[j]
                        out.neighbours = n + 1
                        if d2 < body * body { out.overlapping = true }
                    }
                }
                j += 1
                if j >= end { j = first }
            }
        }

        guard rings > span else {
            out.coveredExactly = out.readEverything ? covered(span, ci, cj, x) : 0
            return out
        }

        let preyBit = UInt8(1) << preyKind.rawValue
        let predatorBit = UInt8(1) << predatorKind.rawValue
        var budget = cap
        var ring = span + 1
        var reached = span
        while ring <= rings {
            let cover = covered(ring - 1, ci, cj, x)
            let cover2 = cover * cover
            let wantPrey = out.preyDistance > cover2
            let wantPredator = out.predatorDistance > cover2
            if !wantPrey && !wantPredator { break }
            if budget <= 0 { break }
            var want: UInt8 = 0
            if wantPrey { want |= preyBit }
            if wantPredator { want |= predatorBit }
            let i0 = max(0, ci - ring)
            let i1 = min(gridWidth - 1, ci + ring)
            if i0 <= i1 {
                var jj = cj - ring
                while jj <= cj + ring {
                    if jj >= 0 && jj < gridHeight {
                        let edge = (jj == cj - ring || jj == cj + ring)
                        let rowBase = jj * gridWidth
                        if !edge || cellStart[rowBase + i1 + 1] != cellStart[rowBase + i0] {
                            let stride = edge ? 1 : 2 * ring
                            var ii = edge ? i0 : ci - ring
                            while ii <= i1 {
                                if ii >= 0 {
                                    let c = rowBase + ii
                                    if cellKinds[c] & want != 0 {
                                        var j = Int(cellStart[c])
                                        let end = Int(cellStart[c + 1])
                                        var taken = 0
                                        while j < end && taken < budget {
                                            let k = mirrorKind[j]
                                            if k == preyKind || k == predatorKind {
                                                let other = mirrorPosition[j]
                                                let delta = other - x
                                                let d2 = delta.x * delta.x + delta.y * delta.y
                                                if k == preyKind {
                                                    if d2 < out.preyDistance {
                                                        out.preyDistance = d2
                                                        out.prey = other
                                                    }
                                                } else if d2 < out.predatorDistance {
                                                    out.predatorDistance = d2
                                                    out.predator = other
                                                    out.predatorIndex = mirrorIndex[j]
                                                }
                                            }
                                            taken += 1
                                            j += 1
                                        }
                                        out.visits += taken
                                        budget -= taken
                                    }
                                }
                                ii += stride
                            }
                        }
                    }
                    jj += 1
                }
            }
            if budget > 0 { reached = ring }
            ring += 1
        }
        out.coveredExactly = out.readEverything ? covered(reached, ci, cj, x) : 0
        return out
    }

    @inline(__always)
    func covered(_ rings: Int, _ ci: Int, _ cj: Int, _ x: SIMD2<Float>) -> Float {
        var c = Float.infinity
        if ci - rings > 0 { c = min(c, x.x - Float(ci - rings) * cellSize.x) }
        if ci + rings < gridWidth - 1 { c = min(c, Float(ci + rings + 1) * cellSize.x - x.x) }
        if cj - rings > 0 { c = min(c, x.y - Float(cj - rings) * cellSize.y) }
        if cj + rings < gridHeight - 1 { c = min(c, Float(cj + rings + 1) * cellSize.y - x.y) }
        return c
    }

    @inline(__always)
    func fieldTarget(_ kind: Kind, at x: SIMD2<Float>) -> SIMD2<Float>? {
        var fi = Int(x.x / fieldCellSize.x)
        var fj = Int(x.y / fieldCellSize.y)
        if fi < 0 { fi = 0 }
        if fi >= fieldWidth { fi = fieldWidth - 1 }
        if fj < 0 { fj = 0 }
        if fj >= fieldHeight { fj = fieldHeight - 1 }
        let base = kind.index * fieldCells
        let radius = Tuning.fieldBlockRadius
        var best = SIMD2<Float>(repeating: .infinity)
        var bestDistance = Float.infinity
        for j in max(0, fj - radius)...min(fieldHeight - 1, fj + radius) {
            for i in max(0, fi - radius)...min(fieldWidth - 1, fi + radius) {
                let candidate = fieldPosition[base + j * fieldWidth + i]
                if candidate.x == .infinity { continue }
                let d = squaredDistance(candidate, x)
                if d < bestDistance {
                    bestDistance = d
                    best = candidate
                }
            }
        }
        return bestDistance == .infinity ? nil : best
    }

    @inline(__always)
    func pairDirection(_ i: Int, _ j: Int) -> SIMD2<Float> {
        let sign: Float = i < j ? 1 : -1
        let d: Float = 0.7071068
        switch (i ^ j ^ ticksRun) & 7 {
        case 0: return SIMD2(sign, 0)
        case 1: return SIMD2(sign * d, sign * d)
        case 2: return SIMD2(0, sign)
        case 3: return SIMD2(-sign * d, sign * d)
        case 4: return SIMD2(-sign, 0)
        case 5: return SIMD2(-sign * d, -sign * d)
        case 6: return SIMD2(0, -sign)
        default: return SIMD2(sign * d, -sign * d)
        }
    }

    func move() {
        let body = tuning.body
        let contact = tuning.contact
        let cap = tuning.displacementCap
        let (low, high) = standingRoom
        var visited = 0
        var worst = worstSoldierVisits
        var longestRow = worstRowLength

        for slot in 0..<soldiers {
            let x = mirrorPosition[slot]
            let me = Int(mirrorIndex[slot])
            let kind = mirrorKind[slot]
            let found = scan(
                slot: slot,
                at: x,
                kind: kind,
                cell: Int(cellOf[me]),
                rings: kernel.exactReachRings,
                collect: true
            )
            visited += found.visits
            if found.visits > worst { worst = found.visits }
            if found.longestRow > longestRow { longestRow = found.longestRow }

            let choice = decide(found, kind: kind, at: x)
            var step = SIMD2<Float>.zero
            if choice.hasTarget {
                if choice.targetDistance > Tuning.coincidenceSquared {
                    let pace = choice.chasing ? tuning.chaseStep : tuning.fleeStep
                    let reach = pace / choice.targetDistance.squareRoot()
                    step = choice.chasing
                        ? (choice.target - x) * reach
                        : (x - choice.target) * reach
                } else if !choice.chasing {
                    step = pairDirection(me, Int(found.predatorIndex)) * tuning.fleeStep
                }
            }

            kindsNext[me] = found.predatorDistance < contact * contact ? kind.beatenBy : kind

            let neighbours = found.neighbours
            for _ in 0..<kernel.constraintPasses {
                var moved = false
                if step.x > high.x - x.x { step.x = high.x - x.x; moved = true }
                if step.x < low.x - x.x { step.x = low.x - x.x; moved = true }
                if step.y > high.y - x.y { step.y = high.y - x.y; moved = true }
                if step.y < low.y - x.y { step.y = low.y - x.y; moved = true }
                for t in 0..<neighbours {
                    let d = neighbourDistance[t]
                    let u = neighbourDelta[t] * (d > 0 ? 1 / d : 1 / body)
                    let approach = step.x * u.x + step.y * u.y
                    let allowed = (d - body) * 0.5
                    if approach > allowed {
                        step -= u * (approach - allowed)
                        moved = true
                    }
                }
                if !moved { break }
            }

            var placed = x + step
            if found.overlapping {
                for _ in 0..<kernel.pushPasses {
                    var moved = false
                    for t in 0..<neighbours {
                        let neighbour = x + neighbourDelta[t]
                        let away = placed - neighbour
                        let d2 = away.x * away.x + away.y * away.y
                        if d2 < body * body {
                            if d2 < Tuning.coincidenceSquared {
                                placed += pairDirection(me, Int(neighbourIndex[t])) * (body * 0.5)
                            } else {
                                let d = d2.squareRoot()
                                placed += away * ((body - d) * 0.5 / d)
                            }
                            moved = true
                        }
                    }
                    if !moved { break }
                }
            }

            var travel = placed - x
            let travel2 = travel.x * travel.x + travel.y * travel.y
            if travel2 > cap * cap { travel *= cap / travel2.squareRoot() }
            placed = x + travel
            positionsNext[me] = placed.clamped(lowerBound: low, upperBound: high)
        }

        candidateVisits += visited
        worstSoldierVisits = worst
        worstRowLength = longestRow
    }

    func step() {
        bin()
        buildFields()
        move()
        swap(&positions, &positionsNext)
        swap(&kinds, &kindsNext)
        recount()
        ticksRun += 1
    }
}
