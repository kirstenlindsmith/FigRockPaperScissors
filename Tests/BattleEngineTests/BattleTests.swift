import Testing

@_spi(Instrumentation) import BattleEngine
@_spi(Instrumentation) import BattleFixtures

@Suite struct BattleTests {
    static let sizes = [3, 6, 15, 30, 60]

    @Test(arguments: Armies.allCases)
    func everyBattleEndsWithOneKindStanding(armies: Armies) throws {
        for soldiers in BattleTests.sizes {
            for seed in UInt64(1)...12 {
                let setup = Fixtures.setup(armies, soldiers: soldiers, seed: seed)
                let battle = Battle(setup)
                let contested = Kind.allCases.filter { setup[$0] > 0 }.count > 1
                let budget = Gate.resolutionTicks(soldiers: soldiers)
                #expect(battle.runToEnd(within: budget))
                #expect(battle.census.isOver)
                if contested {
                    let victor = try #require(battle.census.victor)
                    #expect(battle.census[victor] == setup.count)
                    #expect(battle.tickCount > 0)
                } else {
                    #expect(battle.tickCount == 0)
                }
            }
        }
    }

    @Test(arguments: [UInt64(1), 2, 3, 4])
    func aBattleChangesHandsManyTimesAndStaysLegible(seed: UInt64) {
        let battle = Battle(Fixtures.setup(.even, soldiers: 300, seed: seed))
        var watcher = Watcher(battle)
        while !battle.census.isOver && battle.tickCount < Gate.resolutionTicks(soldiers: 300) {
            battle.tick()
            watcher.observe()
        }
        #expect(battle.census.isOver)
        #expect(watcher.handChangesPerSoldier >= Gate.handChangesPerSoldier)
        #expect(watcher.surges >= Gate.surgesInEveryBattle)
        if watcher.handChangesPerSoldier >= Gate.churnThatNeedsLegibility {
            #expect(watcher.meanKindLifetimeInSeconds >= Gate.kindLifetimeInSeconds)
        }
    }

    @Test(arguments: [3, 6, 15])
    func noKindIsTheEnginesFavourite(soldiers: Int) {
        let seeds = 900
        let won = wins(soldiers: soldiers, seeds: seeds)
        let band = Gate.winnerShareBand(seeds: seeds)
        #expect(won.reduce(0, +) == seeds)
        #expect(band.contains(Double(won.max()!) / Double(seeds)))
        #expect(band.contains(Double(won.min()!) / Double(seeds)))
    }

    @Test(arguments: [15, 30])
    func fillingTheArmiesInAFixedOrderStarvesAKind(soldiers: Int) {
        let seeds = 300
        let won = wins(soldiers: soldiers, seeds: seeds, shuffledFill: false)
        let band = Gate.winnerShareBand(seeds: seeds)
        #expect(won.reduce(0, +) == seeds)
        #expect(Double(won.min()!) / Double(seeds) < band.lowerBound)
    }

    @Test(arguments: [30, 60])
    func theSeedDecidesTheBattle(soldiers: Int) {
        var lengths: [Int] = []
        var winners: Set<Kind> = []
        for seed in UInt64(1)...24 {
            let battle = Battle(Fixtures.setup(.even, soldiers: soldiers, seed: seed))
            #expect(battle.runToEnd(within: Gate.resolutionTicks(soldiers: soldiers)))
            lengths.append(battle.tickCount)
            if let victor = battle.census.victor { winners.insert(victor) }
        }
        #expect(winners.count >= 2)
        let shortest = lengths.min()!
        let longest = lengths.max()!
        #expect(Double(longest) >= Gate.shortestToLongestBattle * Double(shortest))
    }

}
