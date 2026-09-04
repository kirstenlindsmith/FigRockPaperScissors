struct Random {
    var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x123_4567 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func below(_ bound: Int) -> Int { Int(next() % UInt64(bound)) }

    mutating func unit() -> Float { Float(next() >> 40) * (1.0 / 16_777_216.0) }
}

extension Battle {
    func place() {
        guard soldiers > 0 else { return }
        var rng = Random(seed: setup.seed)

        var spacing = 1 / (3 * Float(soldiers)).squareRoot()
        var lx = max(1, Int(arena.x / spacing))
        var ly = max(1, Int(arena.y / spacing))
        var steps = 0
        while lx * ly > Tuning.latticeSitesPerSoldierCeiling * soldiers
            && steps < Tuning.latticeStepGuard {
            spacing *= 2
            lx = max(1, Int(arena.x / spacing))
            ly = max(1, Int(arena.y / spacing))
            steps += 1
        }
        steps = 0
        while lx * ly < soldiers && steps < Tuning.latticeStepGuard {
            spacing *= 0.8
            lx = max(1, Int(arena.x / spacing))
            ly = max(1, Int(arena.y / spacing))
            steps += 1
        }
        let site = SIMD2<Float>(arena.x / Float(lx), arena.y / Float(ly))
        latticeSites = lx * ly
        latticeSpacing = site
        let slack = min(site.x, site.y) - tuning.body
        let jitter = slack > 0 ? Tuning.jitterOfSlack * slack : 0

        var rock = setup.rock
        var paper = setup.paper
        var left = soldiers
        var index = 0

        func settle(_ centre: SIMD2<Float>, wobbling jitter: Float) {
            let wobble = SIMD2<Float>(rng.unit() * 2 - 1, rng.unit() * 2 - 1) * jitter
            positions[index] = centre + wobble
            let drawn = rng.below(left)
            let pick = kernel.shuffledFill ? drawn : 0
            if pick < rock {
                rock -= 1
                kinds[index] = .rock
            } else if pick - rock < paper {
                paper -= 1
                kinds[index] = .paper
            } else {
                kinds[index] = .scissors
            }
            left -= 1
            index += 1
        }

        var unvisited = lx * ly
        var c = 0
        while left > 0 && c < lx * ly {
            if rng.below(unvisited) < left {
                settle(
                    SIMD2((Float(c % lx) + 0.5) * site.x, (Float(c / lx) + 0.5) * site.y),
                    wobbling: jitter
                )
            }
            unvisited -= 1
            c += 1
        }
        while left > 0 { settle(arena * 0.5, wobbling: 0) }
    }
}
