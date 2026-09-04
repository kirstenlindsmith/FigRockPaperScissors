import BattleFixtures
import Testing

@_spi(Instrumentation) import BattleEngine

@Suite struct TimeTests {
    struct Partition {
        var name: String
        var chunks: (Int, inout Random) -> Duration?
    }

    struct Random {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state >> 11
        }
    }

    static func deliver(_ battle: Battle, total: Duration, style: Int, seed: UInt64) {
        var random = Random(state: seed &+ 1)
        var left = total
        while left > .zero {
            var chunk: Duration
            switch style {
            case 0: chunk = Battle.tickDuration
            case 1: chunk = random.next() % 2 == 0 ? .zero : Battle.tickDuration * 3
            case 2:
                chunk = Duration(
                    secondsComponent: 0,
                    attosecondsComponent: Int64(random.next() % 2_232_142_857_142_857)
                )
            case 3: chunk = Battle.tickDuration * 5 + Duration(
                secondsComponent: 0,
                attosecondsComponent: Int64(random.next() % 15_625_000_000_000_000)
            )
            default:
                chunk = Duration(
                    secondsComponent: 0,
                    attosecondsComponent: Int64(random.next() % 78_125_000_000_000_000)
                )
            }
            if chunk > left { chunk = left }
            if chunk == .zero {
                battle.advance(by: .zero)
                continue
            }
            battle.advance(by: chunk)
            left -= chunk
        }
    }

    @Test(arguments: [
        (Armies.even, 15, Float(19.5 / 9)),
        (Armies.lopsided, 60, Float(19.5 / 9)),
        (Armies.even, 3, Float(0.46)),
        (Armies.even, 120, Float(1)),
        (Armies.even, 30, Float(1e30)),
        (Armies.lopsided, 30, Float(1e-30)),
    ])
    func theSameBattleHoweverTimeIsDivided(armies: Armies, soldiers: Int, aspect: Float) {
        let setup = Fixtures.setup(armies, soldiers: soldiers, seed: 11, aspect: aspect)
        let total = Battle.tickDuration * 300
        let whole = Battle(setup)
        whole.advance(by: total)
        let reference = whole.digest()

        for style in 0..<5 {
            for seed in UInt64(1)...4 {
                let part = Battle(setup)
                TimeTests.deliver(part, total: total, style: style, seed: seed)
                #expect(part.digest() == reference)
                #expect(part.tickCount == whole.tickCount)
                #expect(part.elapsed == whole.elapsed)
            }
        }
    }

    @Test func timeAlreadyRunCannotBeUnrun() {
        let setup = Fixtures.setup(.even, soldiers: 30, seed: 3)
        let total = Battle.tickDuration * 200
        let straight = Battle(setup)
        straight.advance(by: total)

        let poked = Battle(setup)
        poked.advance(by: .seconds(-5))
        #expect(poked.tickCount == 0)
        poked.advance(by: total)
        #expect(poked.digest() == straight.digest())
        poked.advance(by: .seconds(-100))
        #expect(poked.tickCount == straight.tickCount)
        #expect(poked.digest() == straight.digest())
    }

    @Test func slicesThinnerThanATickAddUpExactly() {
        let setup = Fixtures.setup(.even, soldiers: 30, seed: 6)
        let sliverAttoseconds: Int64 = 15_625_000_000_000_000 / 7
        let sliver = Duration(secondsComponent: 0, attosecondsComponent: sliverAttoseconds)
        let slices = 700
        let sliced = Battle(setup)
        for _ in 0..<slices { sliced.advance(by: sliver) }
        let earned = Int(Int64(slices) * sliverAttoseconds / 15_625_000_000_000_000)
        let whole = Battle(setup)
        whole.advance(by: Battle.tickDuration * earned)
        #expect(sliced.tickCount == earned)
        #expect(sliced.digest() == whole.digest())
        sliced.advance(by: sliver * 7)
        #expect(sliced.tickCount == earned + 1)
    }

    @Test func speedIsOnlyTheRateOfSampling() {
        let setup = Fixtures.setup(.even, soldiers: 60, seed: 8)
        let frame = Duration(secondsComponent: 0, attosecondsComponent: 16_666_666_666_666_666)
        let slow = Battle(setup)
        let fast = Battle(setup)
        for _ in 0..<80 { slow.advance(by: frame) }
        for _ in 0..<10 { fast.advance(by: frame * 8) }
        #expect(slow.tickCount == fast.tickCount)
        #expect(slow.digest() == fast.digest())
    }

    @Test func aThousandRaggedPartitionsAreOneBattle() {
        let setup = Fixtures.setup(.even, soldiers: 6, seed: 21)
        let total = Battle.tickDuration * 240
        let whole = Battle(setup)
        whole.advance(by: total)
        let reference = whole.digest()
        for seed in UInt64(1)...1000 {
            let part = Battle(setup)
            TimeTests.deliver(part, total: total, style: 3, seed: seed)
            #expect(part.digest() == reference)
            #expect(part.tickCount == whole.tickCount)
        }
    }

    @Test func noDeliverableTimeIsTooMuchToDeliver() {
        let battle = Battle(Fixtures.setup(.even, soldiers: 15, seed: 2))
        let beyondItsComponents = Duration.seconds(Int64.max) * 8
        battle.advance(by: beyondItsComponents)
        #expect(battle.census.isOver)
        #expect(battle.elapsed == Battle.tickDuration * battle.tickCount)
        let ended = battle.digest()
        let ticks = battle.tickCount
        for _ in 0..<40 { battle.advance(by: beyondItsComponents) }
        #expect(battle.digest() == ended)
        #expect(battle.tickCount == ticks)
    }

    @Test func elapsedIsTheBattlesOwnLength() {
        let battle = Battle(Fixtures.setup(.even, soldiers: 15, seed: 4))
        battle.advance(by: .seconds(3))
        #expect(battle.elapsed <= .seconds(3))
        #expect(battle.elapsed == Battle.tickDuration * battle.tickCount)
        let ended = battle.runToEnd(within: 40_000)
        #expect(ended)
        #expect(battle.elapsed == Battle.tickDuration * battle.tickCount)
    }
}
