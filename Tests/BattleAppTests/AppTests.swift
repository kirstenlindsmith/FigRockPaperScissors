import BattleEngine
import Testing

@testable import BattleApp

@Suite struct AppTests {
    static let tapTarget = 44.0
    static let tapFloor = 28.0

    @Test func theAppOpensOnALandingScreen() {
        let screen = Screen(seed: 1)
        let frame = screen.frame(seconds: 0)
        #expect(frame.phase == .landing)
        #expect(frame.soldiers.isEmpty)
        #expect(frame.counts.isEmpty)
        #expect(frame.clock.isEmpty)
        #expect(frame.summary.isEmpty)
        #expect(frame.banner == nil)
        #expect(frame.secondary.isEmpty)
        #expect(!frame.wantsFrames)
        #expect(frame.primary.title == "PLAY")
        #expect(frame.primary.spoken == "Play")
        #expect(frame.primary.intent == .newBattle)
        #expect(frame.layout.field.height > 0)
        #expect(Frame.opening.phase == .landing)
        #expect(Frame.opening.primary.intent == .newBattle)
        #expect(Frame.opening.layout == Layout.zero)
        #expect(!Frame.opening.wantsFrames)
    }

    @Test func oneTapDrawsUpThreeHundredSoldiersOverTheWholeField() {
        let screen = Screen(seed: 1)
        let frame = screen.handle(.newBattle)
        let staged = try! #require(screen.battle)
        #expect(frame.phase == .held)
        #expect(frame.soldiers.count == 300)
        #expect(frame.counts == [100, 100, 100])
        #expect(frame.clock == "0.0 sec")
        #expect(frame.primary.title == "GO")
        #expect(frame.primary.spoken == "Go")
        #expect(!frame.wantsFrames)
        #expect(
            abs(
                Double(staged.setup.aspect)
                    - frame.layout.field.width / frame.layout.field.height) < 1e-6)
        let field = frame.layout.field
        #expect(coverage(of: spots(frame.soldiers), over: field).emptyBlocks == 0)
        #expect(coverage(of: bunched(spots(frame.soldiers), into: field), over: field)
            .emptyBlocks > 0)
        for glyph in 0..<3 {
            let army = frame.soldiers.filter { $0.glyph == glyph }
            let left = army.filter { $0.x < field.width / 2 }.count
            let above = army.filter { $0.y < field.height / 2 }.count
            #expect(army.count == 100)
            #expect(left >= 10 && left <= 90)
            #expect(above >= 10 && above <= 90)
        }
    }

    @Test func everyArmyIsDrawnAsItsOwnEmoji() {
        #expect(Words.glyphs[Int(Kind.rock.rawValue)] == "🪨")
        #expect(Words.glyphs[Int(Kind.paper.rawValue)] == "📄")
        #expect(Words.glyphs[Int(Kind.scissors.rawValue)] == "✂️")
        #expect(Words.roles[Int(Kind.rock.rawValue)] == "Rock")
        #expect(Words.roles[Int(Kind.paper.rawValue)] == "Paper")
        #expect(Words.roles[Int(Kind.scissors.rawValue)] == "Scissors")
        #expect(Words.glyphs.count == Kind.allCases.count)
        #expect(Words.roles.count == Kind.allCases.count)
    }

    @Test func armiesDrawnUpDoNotMove() {
        let screen = Screen(seed: 2)
        var frame = screen.handle(.newBattle)
        for _ in 0..<120 {
            let next = screen.frame()
            #expect(next == frame)
            frame = next
        }
    }

    @Test func goStartsTheClockAndPauseStopsIt() {
        let screen = Screen(seed: 3)
        _ = screen.handle(.newBattle)
        var frame = screen.handle(.go)
        #expect(frame.phase == .watching)
        #expect(frame.primary.title == "PAUSE")
        #expect(frame.primary.spoken == "Pause")
        #expect(frame.wantsFrames)
        frame = screen.run(30)
        #expect(frame.clock != "0.0 sec")
        let stopped = screen.handle(.pause)
        #expect(stopped.phase == .held)
        #expect(stopped.primary.title == "RESUME")
        #expect(stopped.primary.spoken == "Resume")
        #expect(stopped.secondary.map(\.title) == ["START OVER", "ARMIES", "HOME"])
        #expect(stopped.secondary.map(\.spoken) == ["Start over", "Armies", "Home"])
        #expect(!stopped.wantsFrames)
        let held = screen.run(30)
        #expect(held.clock == stopped.clock)
        #expect(held.soldiers == stopped.soldiers)
        let resumed = screen.handle(.go)
        #expect(resumed.phase == .watching)
        #expect(resumed.wantsFrames)
    }

    @Test(arguments: [10.0, 0, -1, 1e300, .nan, .infinity, -.infinity])
    func aFrameNeverHandsTheEngineMoreThanASliceOfTime(ask: Double) {
        let screen = Screen(seed: 4)
        _ = screen.handle(.newBattle)
        _ = screen.handle(.speed(.quintuple))
        _ = screen.handle(.go)
        for _ in 0..<3 {
            let before = screen.elapsed
            let frame = screen.frame(seconds: ask)
            let ticks = Int(((screen.elapsed - before) * 64).rounded())
            #expect(ticks <= 16)
            #expect(frame.soldiers.count == 300)
            if ask.isFinite && ask > 0 {
                #expect(ticks > 0)
            } else {
                #expect(ticks == 0)
            }
        }
        let owed = screen.elapsed
        _ = screen.frame(seconds: 0)
        _ = screen.frame(seconds: 0)
        #expect(screen.elapsed == owed)
    }

    @Test func theSpeedRowNamesAndMarksTheSpeedInPlay() {
        let screen = Screen(seed: 5)
        _ = screen.handle(.newBattle)
        var frame = screen.handle(.go)
        #expect(frame.secondary.map(\.title) == ["1×", "2×", "5×"])
        #expect(
            frame.secondary.map(\.spoken)
                == ["Normal speed", "Double speed", "Five times speed"])
        #expect(
            frame.secondary.map(\.intent) == [.speed(.normal), .speed(.double), .speed(.quintuple)])
        #expect(frame.secondary.filter(\.selected).map(\.intent) == [.speed(.normal)])
        for chosen in Speed.allCases {
            frame = screen.handle(.speed(chosen))
            #expect(frame.secondary.filter(\.selected).map(\.intent) == [.speed(chosen)])
        }
    }

    @Test(arguments: Speed.allCases.filter { $0 != .normal })
    func aSpeedIsExactlyItsMultipleOfTheRate(chosen: Speed) {
        let watched = 40
        let slow = Screen(seed: 5)
        _ = slow.handle(.newBattle)
        _ = slow.handle(.go)
        let single = slow.run(watched * chosen.rawValue)
        let fast = Screen(seed: 5)
        _ = fast.handle(.newBattle)
        _ = fast.handle(.speed(chosen))
        _ = fast.handle(.go)
        let multiplied = fast.run(watched)
        #expect(single.soldiers == multiplied.soldiers)
        #expect(single.counts == multiplied.counts)
        #expect(single.clock == multiplied.clock)
        #expect(single.clock != "0.0 sec")
    }

    @Test func pausingChangesNoBattle() {
        let straight = Screen(seed: 6)
        _ = straight.handle(.newBattle)
        _ = straight.handle(.go)
        let uninterrupted = straight.run(120)

        let interrupted = Screen(seed: 6)
        _ = interrupted.handle(.newBattle)
        _ = interrupted.handle(.go)
        _ = interrupted.run(60)
        _ = interrupted.handle(.pause)
        _ = interrupted.run(200)
        _ = interrupted.handle(.go)
        let resumed = interrupted.run(60)

        #expect(resumed.soldiers == uninterrupted.soldiers)
        #expect(resumed.counts == uninterrupted.counts)
        #expect(resumed.clock == uninterrupted.clock)
    }

    @Test func startingOverIsNotARerun() {
        let screen = Screen(seed: 7)
        var openings: [[Dot]] = []
        for _ in 0..<4 { openings.append(screen.handle(.newBattle).soldiers) }
        for (index, one) in openings.enumerated() {
            for other in openings[(index + 1)...] { #expect(sharedSpots(one, other) == 0) }
        }
        let again = Screen(seed: 7)
        #expect(again.handle(.newBattle).soldiers == openings[0])
    }

    @Test func goingHomeReleasesTheBattle() {
        let screen = Screen(seed: 8)
        _ = screen.handle(.newBattle)
        weak var held = screen.battle
        #expect(held != nil)
        let frame = screen.handle(.home)
        #expect(held == nil)
        #expect(frame.phase == .landing)
        #expect(frame.soldiers.isEmpty)
        #expect(frame.primary.title == "PLAY")
    }

    @Test func aWholeBattleIsDrawnInsideTheFieldAndEndsCelebrated() {
        let screen = Screen(seed: pinned)
        _ = screen.handle(.newBattle)
        _ = screen.handle(.speed(.double))
        var frame = screen.handle(.go)
        let field = frame.layout.field
        var frames = 0
        while frame.phase != .finished {
            frame = screen.frame()
            frames += 1
            #expect(frames < 5_000)
            let half = frame.soldierPoints / 2
            var tally = [0, 0, 0]
            for dot in frame.soldiers {
                #expect(dot.x - half >= 0 && dot.x + half <= field.width)
                #expect(dot.y - half >= 0 && dot.y + half <= field.height)
                tally[dot.glyph] += 1
            }
            #expect(tally == frame.counts)
            #expect(tally.reduce(0, +) == 300)
            for index in tally.indices {
                #expect(frame.summary.contains("\(frame.armies[index].name) \(tally[index])"))
            }
        }
        let winner = try! #require(frame.counts.firstIndex(of: 300))
        let banner = try! #require(frame.banner)
        let reading = Clock.tenths(try! #require(screen.battle).elapsed)
        #expect(banner.winner == "\(frame.armies[winner].glyph) wins!")
        #expect(frame.clock == "\(reading) sec")
        #expect(banner.duration == "\(reading) seconds")
        #expect(banner.spoken == "\(frame.armies[winner].name) wins after \(reading) seconds")
        #expect(frame.summary.hasSuffix("\(reading) seconds"))
        #expect(frame.soldiers.allSatisfy { $0.glyph == winner })
        #expect(!frame.confetti.isEmpty)
        #expect(frame.confetti.allSatisfy { $0.glyph == winner })
        #expect(frame.primary.title == "PLAY AGAIN")
        #expect(frame.primary.spoken == "Play again")
        #expect(frame.secondary.map(\.title) == ["HOME"])
        #expect(frame.secondary.map(\.spoken) == ["Home"])
        let frozen = frame.clock
        #expect(screen.frame(seconds: -1) == frame)
        var party = 0.0
        for _ in 0..<600 where !frame.confetti.isEmpty {
            frame = screen.frame()
            party += refresh
        }
        #expect(frame.clock == frozen)
        #expect(frame.soldiers.count == 300)
        #expect(frame.confetti.isEmpty)
        #expect(!frame.wantsFrames)
        #expect(party > Confetti.span - 0.1)
        #expect(party < Confetti.span + 0.1)
    }

    @Test func confettiFallsAndThenStops() {
        let staged = Screen(seed: 11).handle(.newBattle)
        let field = staged.layout.field
        let points = staged.confettiPoints
        #expect(points > staged.soldierPoints)
        for index in 0..<Confetti.pieces {
            var previous = -Double.infinity
            var falling = true
            for step in 0...31 {
                let dot = Confetti.piece(
                    index, glyph: 2, seconds: Double(step) / 10, field: field, points: points)
                guard let dot else {
                    falling = false
                    continue
                }
                #expect(falling)
                #expect(dot.y > previous)
                #expect(dot.x - points / 2 >= 0 && dot.x + points / 2 <= field.width)
                if step == 0 { #expect(dot.y + points / 2 <= 0) }
                previous = dot.y
            }
            #expect(!falling)
        }
        for step in 0...30 {
            let seconds = Double(step) / 10
            let dots = Confetti.dots(
                glyph: 2, seconds: seconds, field: field, points: points, reduceMotion: false)
            #expect(dots.allSatisfy { $0.glyph == 2 })
            if seconds <= Confetti.fall { #expect(dots.count == Confetti.pieces) }
            if seconds < Confetti.span { #expect(!dots.isEmpty) } else { #expect(dots.isEmpty) }
        }
        #expect(
            Confetti.dots(
                glyph: 2, seconds: 0, field: field, points: points, reduceMotion: true).isEmpty)
    }

    @Test func theFieldIsNeverDistorted() {
        for surface in screens {
            let layout = Layout(surface, diameter: Director.diameter)
            let band = layout.field
            let setup = Choices.opening.setup(aspect: band.width / band.height, seed: 0)
            let arena = Size(width: Double(setup.arena.x), height: Double(setup.arena.y))
            let diameter = Double(setup.soldierDiameter)
            let field = Field(arena: arena, diameter: diameter, size: band)
            let half = field.ink / 2
            #expect(field.ink >= Layout.legibleInk)
            #expect(abs((field.x(1) - field.x(0)) - (field.y(1) - field.y(0))) < 1e-12)
            #expect(abs(field.originX - (band.width - arena.width * field.scale) / 2) < 1e-9)
            #expect(abs(field.originY - (band.height - arena.height * field.scale) / 2) < 1e-9)
            #expect(field.x(0) - half >= -1e-9)
            #expect(field.y(0) - half >= -1e-9)
            #expect(field.x(arena.width) + half <= band.width + 1e-9)
            #expect(field.y(arena.height) + half <= band.height + 1e-9)
        }
    }

    @Test func theTitleFillsTheFieldBandWithoutOutgrowingIt() {
        for surface in screens {
            let layout = Layout(surface, diameter: Director.diameter)
            #expect(layout.art > 0)
            #expect(3 * layout.art + 2 * layout.gap <= layout.field.height)
        }
    }

    @Test func everyControlStaysBigEnoughToHitOnEveryScreenAndTextSize() {
        for surface in screens {
            let layout = Layout(surface, diameter: Director.diameter)
            #expect(layout.primary >= AppTests.tapTarget, "\(surface)")
            #expect(layout.secondary >= AppTests.tapFloor, "\(surface)")
        }
    }

    @Test func theReadoutBandStaysTallerThanTheReadingsItShows() {
        for surface in screens {
            let layout = Layout(surface, diameter: Director.diameter)
            #expect(layout.readout > layout.body, "\(surface)")
        }
    }

    @Test func anUnusableSurfaceStagesNothingAndStillOffersAWayOn() {
        let unusable = [
            Surface.zero,
            Surface(width: 402, height: 0, unit: 1, reduceMotion: false),
            Surface(width: 0, height: 778, unit: 1, reduceMotion: false),
            Surface(width: .nan, height: .nan, unit: .nan, reduceMotion: false),
        ]
        for surface in unusable {
            let screen = Screen(seed: 9, surface: surface)
            let frame = screen.handle(.newBattle)
            #expect(screen.battle == nil)
            #expect(frame.phase == .landing)
            #expect(frame.soldiers.isEmpty)
            #expect(frame.primary.intent == .newBattle)
            #expect(frame.layout.primary == 0)
            #expect(frame.layout.field.width * frame.layout.field.height == 0)
            screen.surface = device
            #expect(screen.handle(.newBattle).soldiers.count == 300)
        }
    }

    @Test func theClockReadsWhatHasPassed() {
        let readings: [(Duration, String)] = [
            (.zero, "0.0"),
            (.seconds(-5), "0.0"),
            (.seconds(0.984375), "0.9"),
            (.seconds(0.99999), "0.9"),
            (.seconds(1), "1.0"),
            (.seconds(13.703125), "13.7"),
            (.seconds(59.984375), "59.9"),
            (.seconds(600), "600.0"),
        ]
        for (elapsed, reading) in readings { #expect(Clock.tenths(elapsed) == reading) }
    }

    @Test func everyPhaseOffersAWayOn() {
        let intents: [Intent] =
            [.newBattle, .go, .pause, .home, .armies] + Speed.allCases.map { Intent.speed($0) }
        let surfaces = [
            device,
            Surface(width: 402, height: 778, unit: 3, reduceMotion: true),
            .zero,
        ]
        let asks = [refresh, 0, -1, .nan, 1e300, 10]
        let screen = Screen(seed: 10)
        var step = 0
        for _ in 0..<3 {
            for intent in intents {
                for ask in asks {
                    step += 1
                    screen.surface = surfaces[step % surfaces.count]
                    var frame = screen.handle(intent)
                    #expect(!frame.primary.title.isEmpty)
                    #expect(frame.soldiers.count == 0 || frame.soldiers.count == 300)
                    switch frame.phase {
                    case .landing, .choosing: #expect(frame.secondary.isEmpty)
                    case .watching: #expect(frame.secondary.allSatisfy { $0.intent != .home })
                    case .held, .finished:
                        #expect(frame.secondary.contains { $0.intent == .home })
                    }
                    #expect(screen.frame(seconds: 0) == frame)
                    let phase = frame.phase
                    let before = screen.elapsed
                    frame = screen.frame(seconds: ask)
                    if phase != .watching { #expect(screen.elapsed == before) }
                }
            }
        }
    }

    @Test func aSecondBattleCelebratesToo() {
        let screen = Screen(seed: pinned)
        _ = screen.handle(.newBattle)
        _ = screen.handle(.speed(.double))
        _ = screen.handle(.go)
        var frame = screen.runToEnd(within: 5_000)
        #expect(frame.phase == .finished)
        #expect(!frame.confetti.isEmpty)
        frame = screen.run(200)
        #expect(frame.confetti.isEmpty)
        #expect(!frame.wantsFrames)

        frame = screen.handle(.newBattle)
        #expect(frame.phase == .held)
        _ = screen.handle(.go)
        frame = screen.runToEnd(within: 5_000)
        #expect(frame.phase == .finished)
        #expect(frame.confetti.count == Confetti.pieces)
        #expect(frame.wantsFrames)
    }
}
