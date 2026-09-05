import BattleFixtures
import Foundation
import Testing

@_spi(Instrumentation) import BattleEngine

@Suite struct SurfaceTests {
    @Test func reportsEverySoldierAndEveryCountAtEveryMoment() {
        let setup = Fixtures.setup(.even, soldiers: 60, seed: 4)
        let battle = Battle(setup)
        for _ in 0...200 {
            let census = battle.census
            let kinds = battle.kindsNow
            #expect(kinds.count == setup.count)
            #expect(battle.positionsNow.count == setup.count)
            for kind in Kind.allCases {
                #expect(census[kind] == kinds.filter { $0 == kind }.count)
            }
            #expect(census.total == setup.count)
            #expect(battle.elapsed == Battle.tickDuration * battle.tickCount)
            battle.tick()
        }
        #expect(battle.tickCount > 0)
    }

    @Test func armiesAreExactlyWhatTheSetupAsksFor() {
        for soldiers in [3, 7, 60, 301] {
            for armies in Armies.allCases {
                let setup = Fixtures.setup(armies, soldiers: soldiers, seed: 9)
                let census = Battle(setup).census
                for kind in Kind.allCases {
                    #expect(census[kind] == setup[kind])
                }
            }
        }
    }

    @Test func aBattleWithNoSoldiersIsOverWithNoWinner() {
        let empty = Setup(aspect: 2, seed: 1, rock: 0, paper: 0, scissors: 0)
        let battle = Battle(empty)
        #expect(battle.census.total == 0)
        #expect(battle.census.isOver)
        #expect(battle.census.victor == nil)
        battle.advance(by: .seconds(10))
        #expect(battle.elapsed == .zero)
        #expect(battle.withSoldiers { positions, _ in positions.count } == 0)
    }

    @Test func aBattleOfOneKindIsOverAtTheStartWithAWinner() {
        let setup = Setup(aspect: 1, seed: 3, rock: 0, paper: 25, scissors: 0)
        let battle = Battle(setup)
        #expect(battle.census.isOver)
        #expect(battle.census.victor == .paper)
        battle.advance(by: .seconds(30))
        #expect(battle.elapsed == .zero)
        #expect(battle.census[.paper] == 25)
    }

    @Test func timeStopsChangingAFinishedBattle() {
        let battle = Battle(Fixtures.setup(.even, soldiers: 15, seed: 2))
        #expect(battle.runToEnd(within: 20_000))
        let end = battle.digest()
        let ticks = battle.tickCount
        let elapsed = battle.elapsed
        battle.advance(by: .seconds(600))
        #expect(battle.digest() == end)
        #expect(battle.tickCount == ticks)
        #expect(battle.elapsed == elapsed)
    }

    @Test func victorIsTheOneKindLeft() throws {
        let battle = Battle(Fixtures.setup(.even, soldiers: 30, seed: 5))
        #expect(battle.census.victor == nil)
        #expect(battle.runToEnd(within: 40_000))
        let victor = try #require(battle.census.victor)
        #expect(battle.census[victor] == 30)
        #expect(battle.census.total == 30)
    }

    @Test(arguments: [Float(0), -1, .nan, .infinity, -.infinity, 1e30, 1e-30, 0.46, 2.2])
    func everyAspectMakesARunnableBattle(aspect: Float) {
        let setup = Fixtures.setup(.even, soldiers: 30, seed: 7, aspect: aspect)
        #expect(setup.aspect.isFinite && setup.aspect > 0)
        let arena = setup.arena
        #expect(arena.x.isFinite && arena.y.isFinite)
        #expect(abs(arena.x * arena.y - 1) < 1e-4)
        let battle = Battle(setup)
        battle.run(ticks: 100)
        for position in battle.positionsNow {
            #expect(position.x.isFinite && position.y.isFinite)
            #expect(position.x >= battle.insetLow.x && position.x <= battle.insetHigh.x)
            #expect(position.y >= battle.insetLow.y && position.y <= battle.insetHigh.y)
        }
    }

    @Test func anInvalidSetupCannotBeConstructed() {
        var setup = Setup(aspect: .nan, seed: 0, rock: -5, paper: 0, scissors: 3)
        #expect(setup.aspect == 1)
        #expect(setup.rock == 0)
        #expect(setup.scissors == 3)
        setup.aspect = -2
        setup.scissors = -1
        setup[.paper] = .min
        #expect(setup.aspect == 1)
        #expect(setup.scissors == 0)
        #expect(setup.paper == 0)
        #expect(setup.count == 0)
    }

    @Test func aSetupDecodedFromValuesOutOfRangeNormalisesLikeAConstructedOne() throws {
        let stored = """
        {"aspect":-3.5,"seed":42,"rock":-9,"paper":4,"scissors":2}
        """
        let decoded = try JSONDecoder().decode(Setup.self, from: Data(stored.utf8))
        let built = Setup(aspect: -3.5, seed: 42, rock: -9, paper: 4, scissors: 2)
        #expect(decoded == built)
        #expect(Battle(decoded).digest() == Battle(built).digest())
    }

    @Test func bytesThatAreNotASetupAreADecodingErrorTheCallerMustHandle() {
        let broken: [Data] = [
            Data(#"{"aspect":2.1,"seed":42,"rock":1,"paper":1"#.utf8),
            Data(#"{"aspect":2.1,"seed":42,"rock":1,"paper":1}"#.utf8),
            Data(#"{"aspect":"wide","seed":42,"rock":1,"paper":1,"scissors":1}"#.utf8),
            Data([0x8f, 0x00, 0xff, 0x21, 0x7e]),
            Data(),
        ]
        for bytes in broken {
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(Setup.self, from: bytes)
            }
        }
    }

    @Test func aSetupSurvivesBeingStoredAndReopened() throws {
        let setup = Fixtures.setup(.lopsided, soldiers: 900, seed: 77, aspect: 0.46)
        let reopened = try JSONDecoder().decode(
            Setup.self, from: try JSONEncoder().encode(setup)
        )
        #expect(reopened == setup)
        #expect(reopened.arena == setup.arena)
        #expect(Battle(reopened).digest() == Battle(setup).digest())
    }

    @Test func aCountBeyondWhatTheEngineCanFieldIsCutDownToIt() {
        let setup = Setup(aspect: 2, seed: 1, rock: .max, paper: .max, scissors: .max)
        #expect(setup.rock > 0 && setup.rock < .max)
        #expect(setup.count == 3 * setup.rock)
        #expect(setup.arena.x.isFinite && setup.arena.y.isFinite)
        #expect(abs(setup.arena.x * setup.arena.y - 1) < 1e-4)
        #expect(setup.soldierDiameter > 0 && setup.soldierDiameter.isFinite)
        #expect(setup.storageBytes > 1 << 30)

        var trimmed = setup
        for kind in Kind.allCases { trimmed[kind] = 1_000 }
        #expect(trimmed.storageBytes < 1 << 20)
        #expect(Battle(trimmed).census.total == 3_000)
    }

    @Test func whatABattleCostsToHoldIsKnownBeforeItIsBuilt() {
        var last = Fixtures.setup(.even, soldiers: 1, seed: 1).storageBytes
        #expect(Fixtures.setup(.even, soldiers: 0, seed: 1).storageBytes == last)
        for soldiers in [300, 250_000] {
            let setup = Fixtures.setup(.even, soldiers: soldiers, seed: 1)
            #expect(setup.storageBytes > last)
            #expect(setup.storageBytes < 1 << 30)
            last = setup.storageBytes
        }
    }

    @Test func oneSoldierIsABattleThatIsAlreadyWon() {
        let setup = Setup(aspect: 2.2, seed: 8, rock: 1, paper: 0, scissors: 0)
        let battle = Battle(setup)
        #expect(battle.census.victor == .rock)
        #expect(battle.census.isOver)
        battle.advance(by: .seconds(5))
        #expect(battle.tickCount == 0)
        let only = battle.positionsNow[0]
        #expect(only.x.isFinite && only.y.isFinite)
    }

    @Test func theArenaCarriesTheScreenAndKeepsItsArea() {
        let aspects: [Float] = [0.46, 1, 19.5 / 9, 2.2]
        for aspect in aspects {
            for soldiers in [3, 60, 6000, 250_000] {
                let setup = Fixtures.setup(.even, soldiers: soldiers, seed: 1, aspect: aspect)
                let arena = setup.arena
                let area: Float = arena.x * arena.y
                let realised: Float = arena.x / arena.y
                #expect(abs(area - 1) < 1e-4)
                #expect(abs(realised - aspect) < 1e-3 * aspect)
            }
        }
    }

    @Test func theArenaIsNeverThinnerThanTwoBodiesNorLongerThanTheFloatGrid() {
        let extremes: [Float] = [1e-30, 1e-3, 0.46, 1, 2.2, 1e3, 1e30]
        for aspect in extremes {
            for soldiers in [1, 2, 3, 30, 6000, 1_000_000] {
                let setup = Fixtures.setup(.even, soldiers: soldiers, seed: 1, aspect: aspect)
                let arena = setup.arena
                let body = 0.9 * setup.soldierDiameter
                let short = min(arena.x, arena.y)
                let long = max(arena.x, arena.y)
                #expect(abs(arena.x * arena.y - 1) < 1e-4)
                #expect(short >= 2 * body * 0.999)
                #expect(long / body <= 65_536 * 1.001)
            }
        }
    }

    @Test func onAPhoneTheClampsBindOnlyAtTheEndsOfWhatTheSurfaceAccepts() {
        let phone = Fixtures.phoneAspect
        func realised(_ soldiers: Int) -> Float {
            let setup = Fixtures.setup(.even, soldiers: soldiers, seed: 1, aspect: phone)
            return setup.arena.x / setup.arena.y
        }
        #expect(realised(1) < 0.999 * phone)
        for soldiers in [2, 300, 24_000, 1_000_000, 400_000_000] {
            #expect(abs(realised(soldiers) - phone) < 1e-3 * phone)
        }
        let largest = Setup(aspect: phone, seed: 1, rock: .max, paper: .max, scissors: .max)
        #expect(largest.count > 400_000_000)
        #expect(largest.arena.x / largest.arena.y < 0.999 * phone)
    }

    @Test func aSteeperScreenOnlyChangesTheShapeTheCallerAsksFor() {
        let requested: Float = 3.0
        let setup = Fixtures.setup(.even, soldiers: 300, seed: 1, aspect: requested)
        #expect(abs(setup.arena.x / setup.arena.y - requested) < 1e-3)
        let steeper = Fixtures.setup(.even, soldiers: 300, seed: 1, aspect: 1 / requested)
        #expect(abs(steeper.arena.y / steeper.arena.x - requested) < 1e-3)
        #expect(abs(setup.arena.x - steeper.arena.y) < 1e-5)
    }

    @Test func theSoldierDiameterIsTheReachThatConverts() {
        let setup = Fixtures.setup(.even, soldiers: 300, seed: 1)
        let battle = Battle(setup)
        #expect(setup.soldierDiameter == battle.scale.contact)
        #expect(battle.scale.body < battle.scale.contact)
        #expect(battle.scale.contact < battle.scale.interaction)
    }
}
