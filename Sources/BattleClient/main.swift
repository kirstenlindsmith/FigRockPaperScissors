import BattleEngine

let setup = Setup(
    aspect: 9.0 / 19.5,
    seed: 7,
    rock: 100,
    paper: 100,
    scissors: 100
)

let battle = Battle(setup)
let frame = Duration(secondsComponent: 0, attosecondsComponent: 16_666_666_666_666_666)
let speed = 4

print(
    "setup count=\(setup.count) arena=\(setup.arena) glyph=\(setup.soldierDiameter)"
        + " storageBytes=\(setup.storageBytes)"
)

var frames = 0
while battle.census.victor == nil && frames < 20_000 {
    battle.advance(by: frame * speed)
    battle.withSoldiers { positions, kinds in
        precondition(positions.count == setup.count && kinds.count == setup.count)
    }
    frames += 1
}

let census = battle.census
precondition(census.isOver && census.total == setup.count)
let victor = census.victor!
print("victor=\(victor) after=\(battle.elapsed) frames=\(frames) count=\(census[victor])")
