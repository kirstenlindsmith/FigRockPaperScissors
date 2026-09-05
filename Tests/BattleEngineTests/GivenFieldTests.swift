import BattleEngine
import BattleFixtures
import Testing

@Suite struct GivenFieldTests {
    static let aspects: [Float] = screens + [0, -1, .nan, .infinity, -.infinity]

    @Test func theBattleFieldsTheFieldItWasGiven() {
        let arena = arena(soldiers: 6, aspect: 2.2)
        let field: [(SIMD2<Float>, Kind)] = [
            (arena * 0.25, .rock),
            (arena * 0.5, .scissors),
            (arena * 0.75, .rock),
            (SIMD2(arena.x * 0.25, arena.y * 0.75), .paper),
            (SIMD2(arena.x * 0.75, arena.y * 0.25), .rock),
            (arena * 0.5, .scissors),
        ]
        let battle = Battle(placing: field, aspect: 2.2)
        #expect(battle.census.total == 6)
        #expect(battle.census[.rock] == 3)
        #expect(battle.census[.paper] == 1)
        #expect(battle.census[.scissors] == 2)
        #expect(battle.census.victor == nil)
        battle.withSoldiers { positions, kinds in
            #expect(positions.count == 6)
            #expect(kinds.count == 6)
            for i in field.indices {
                #expect(positions[i] == field[i].0)
                #expect(kinds[i] == field[i].1)
            }
        }
        #expect(battle.arena == arena)
        #expect(
            battle.soldierDiameter
                == Setup(aspect: 2.2, seed: 1, rock: 6, paper: 0, scissors: 0).soldierDiameter)
    }

    @Test(arguments: screens)
    func aSoldierStandsWhereItWasPutOrOnTheEdgeThatHoldsIt(aspect: Float) {
        func edge(_ given: Float, low: Float, high: Float) -> Float {
            if given.isNaN { return low }
            if given < low { return low }
            if given > high { return high }
            return given
        }
        let field = wildField(aspect: aspect)
        let battle = Battle(placing: field, aspect: aspect)
        let low = battle.insetLow
        let high = battle.insetHigh
        var composedOutside = 0
        battle.withSoldiers { positions, kinds in
            for i in field.indices {
                let given = field[i].0
                #expect(positions[i].x == edge(given.x, low: low.x, high: high.x))
                #expect(positions[i].y == edge(given.y, low: low.y, high: high.y))
                #expect(kinds[i] == field[i].1)
                let inside =
                    given.x >= low.x && given.x <= high.x && given.y >= low.y && given.y <= high.y
                if !inside { composedOutside += 1 }
            }
        }
        #expect(composedOutside == 13)
    }

    @Test func aFieldWithNoSoldiersIsTheEmptyBattle() {
        let battle = Battle(placing: [], aspect: 2.2)
        #expect(battle.census.total == 0)
        #expect(battle.census.isOver)
        #expect(battle.census.victor == nil)
        battle.advance(by: .seconds(10))
        #expect(battle.elapsed == .zero)
        #expect(battle.withSoldiers { positions, _ in positions.count } == 0)
    }

    @Test func aGivenFieldOfOneKindIsABattleAlreadyWonAndItsPileStaysAPile() {
        let point = arena(soldiers: 30, aspect: 2.2) * 0.5
        let field = (0..<30).map { _ in (point, Kind.paper) }
        let battle = Battle(placing: field, aspect: 2.2)
        #expect(battle.census.isOver)
        #expect(battle.census.victor == .paper)
        #expect(battle.census[.paper] == 30)
        battle.advance(by: .seconds(30))
        #expect(battle.elapsed == .zero)
        #expect(battle.withSoldiers { positions, _ in positions.allSatisfy { $0 == point } })
    }

    @Test func theSameFieldGivesTheSameBattle() {
        let field = pileInACorner(60)
        let first = Battle(placing: field, aspect: Fixtures.phoneAspect)
        let second = Battle(placing: field, aspect: Fixtures.phoneAspect)
        for _ in 0..<200 {
            first.advance(by: .milliseconds(16))
            second.advance(by: .milliseconds(16))
            #expect(
                first.withSoldiers { p, _ in Array(p) } == second.withSoldiers { p, _ in Array(p) })
            #expect(
                first.withSoldiers { _, k in Array(k) } == second.withSoldiers { _, k in Array(k) })
        }
        #expect(first.elapsed == second.elapsed)
        #expect(first.census.total == second.census.total)
    }

    @Test(arguments: aspects)
    func everyScreenShapeGivesARunnableGivenBattle(aspect: Float) {
        let battle = Battle(placing: wildField(aspect: aspect), aspect: aspect)
        #expect(battle.arena == arena(soldiers: 14, aspect: aspect))
        #expect(battle.arena.x.isFinite && battle.arena.y.isFinite)
        #expect(abs(battle.arena.x * battle.arena.y - 1) < 1e-4)
        #expect(battle.soldierDiameter > 0 && battle.soldierDiameter.isFinite)
        for _ in 0..<100 {
            battle.advance(by: .milliseconds(16))
            battle.withSoldiers { positions, _ in
                for p in positions {
                    #expect(p.x.isFinite && p.y.isFinite)
                    #expect(p.x >= 0 && p.x <= battle.arena.x)
                    #expect(p.y >= 0 && p.y <= battle.arena.y)
                }
            }
        }
    }
}
