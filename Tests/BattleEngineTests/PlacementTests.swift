import BattleFixtures
import Testing

@_spi(Instrumentation) import BattleEngine

@Suite struct PlacementTests {
    @Test(arguments: screens)
    func everySoldierStandsInsideTheArenaOnALatticeWiderThanABody(aspect: Float) {
        for soldiers in [3, 60, 1500] {
            for seed in UInt64(4)...5 {
                let battle = Battle(
                    Fixtures.setup(.even, soldiers: soldiers, seed: seed, aspect: aspect)
                )
                for position in battle.positionsNow {
                    #expect(position.x >= battle.insetLow.x && position.x <= battle.insetHigh.x)
                    #expect(position.y >= battle.insetLow.y && position.y <= battle.insetHigh.y)
                }
                let sites = Double(battle.latticeSiteCount) / Double(soldiers)
                #expect(Gate.latticeSitesPerSoldier.contains(sites))
                #expect(min(battle.latticeSiteSpacing.x, battle.latticeSiteSpacing.y)
                    > battle.scale.body)
            }
        }
    }

    @Test(arguments: screens)
    func theArmyCoversTheFieldWhereAClumpOfItCouldNot(aspect: Float) {
        for soldiers in [300, 1500] {
            let setup = Fixtures.setup(.even, soldiers: soldiers, seed: 1, aspect: aspect)
            let across = Float(soldiers).squareRoot().rounded(.up)
            let step = 0.1 * min(setup.arena.x, setup.arena.y) / across
            let spots = clumped(soldiers, apart: step, around: setup.arena * 0.5)
            let bunched = hand(
                spots.enumerated().map { ($0.element, Kind.allCases[$0.offset % 3]) },
                aspect: aspect
            )
            #expect(Coverage(Battle(setup)).emptyBlocks == 0)
            #expect(Coverage(bunched).emptyBlocks > 0)
        }
    }

    @Test func theThreeKindsStandMixedThroughTheFieldBecauseTheDrawMixesThem() {
        for soldiers in [300, 1500, 6000] {
            for armies in Armies.allCases {
                for seed in UInt64(1)...3 {
                    let setup = Fixtures.setup(armies, soldiers: soldiers, seed: seed)
                    let band = Gate.mixingBand(setup)
                    #expect(band.contains(Battle(setup).spacingNow().mixedNearest))
                    let inOrder = Battle(setup, shuffledFill: false)
                    #expect(inOrder.spacingNow().mixedNearest < band.lowerBound)
                }
            }
        }
    }

    @Test func theSameSeedDrawsTheSameArmies() {
        let setup = Fixtures.setup(.even, soldiers: 900, seed: 77)
        #expect(Battle(setup).positionsNow == Battle(setup).positionsNow)
        var other = setup
        other.seed = 78
        #expect(Battle(setup).positionsNow != Battle(other).positionsNow)
    }

    @Test func whereSoldiersStandIsSettledBeforeWhichKindsTheyAre() {
        for soldiers in [3, 300, 1500] {
            let setup = Fixtures.setup(.even, soldiers: soldiers, seed: 6)
            let ground = Battle(setup).positionsNow
            #expect(Battle(Fixtures.setup(.lopsided, soldiers: soldiers, seed: 6)).positionsNow
                == ground)
            #expect(Battle(setup, shuffledFill: false).positionsNow == ground)
            #expect(Battle(setup, shuffledFill: false).kindsNow != Battle(setup).kindsNow)
        }
    }

    @Test(arguments: [300, 1500])
    func noTwoSeedsDrawTheSameGround(soldiers: Int) {
        let grounds = (UInt64(1)...12).map {
            Set(Battle(Fixtures.setup(.even, soldiers: soldiers, seed: $0)).positionsNow)
        }
        for (i, one) in grounds.enumerated() {
            for other in grounds[(i + 1)...] { #expect(one.intersection(other).isEmpty) }
        }
    }
}
