@_spi(Instrumentation) import BattleFixtures
import Testing

@_spi(Instrumentation) import BattleEngine

@Suite struct DeterminismTests {
    static let corpus: [(Armies, Int, Float)] = [
        (.even, 3, 19.5 / 9),
        (.even, 60, 19.5 / 9),
        (.lopsided, 60, 19.5 / 9),
        (.even, 300, 19.5 / 9),
        (.even, 30, 0.46),
        (.even, 30, 1),
        (.lopsided, 120, 2.2),
        (.even, 30, 1e30),
        (.lopsided, 300, 1e-30),
    ]

    @Test func oneSetupIsOneBattleTickByTick() {
        let setup = Fixtures.setup(.even, soldiers: 300, seed: 12)
        let first = Battle(setup)
        let second = Battle(setup)
        for _ in 0..<200 {
            first.tick()
            second.tick()
            #expect(first.digest() == second.digest())
        }
        #expect(first.positionsNow == second.positionsNow)
        #expect(first.kindsNow == second.kindsNow)
    }

    @Test func everySetupHasItsOwnBattle() {
        var digests: Set<UInt64> = []
        for (armies, soldiers, aspect) in DeterminismTests.corpus {
            let battle = Battle(Fixtures.setup(armies, soldiers: soldiers, seed: 1, aspect: aspect))
            battle.run(ticks: 120)
            digests.insert(battle.digest())
        }
        #expect(digests.count == DeterminismTests.corpus.count)
    }

    @Test func everySeedHasItsOwnBattle() {
        var digests: Set<UInt64> = []
        for seed in UInt64(1)...25 {
            let battle = Battle(Fixtures.setup(.even, soldiers: 60, seed: seed))
            battle.run(ticks: 60)
            digests.insert(battle.digest())
        }
        #expect(digests.count == 25)
    }

    @Test func watchingABattleDoesNotChangeIt() {
        let setup = Fixtures.setup(.lopsided, soldiers: 300, seed: 5)
        let quiet = Battle(setup)
        let watched = Battle(setup)
        for _ in 0..<150 {
            quiet.tick()
            watched.tick()
            _ = watched.densestCell()
            _ = watched.spacingNow()
            _ = watched.steeringSamples(stride: 29)
            _ = watched.auditSearch(stride: 97)
        }
        #expect(watched.digest() == quiet.digest())
        #expect(watched.tickCount == quiet.tickCount)
    }

    @Test func aBattleIsTheSameAtEveryOptimisationLevel() {
        for (armies, soldiers, aspect, ticks, digest) in Goldens.digests {
            let battle = Battle(Fixtures.setup(armies, soldiers: soldiers, seed: 1, aspect: aspect))
            battle.advance(by: Battle.tickDuration * ticks)
            #expect(battle.tickCount == min(ticks, battle.tickCount))
            #expect(battle.digest() == digest)
        }
    }
}
