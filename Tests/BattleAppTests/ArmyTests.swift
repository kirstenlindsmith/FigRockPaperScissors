import BattleEngine
import Testing

@testable import BattleApp

private func verbatim(_ one: String, _ other: String) -> Bool {
    Array(one.utf8) == Array(other.utf8)
}

@Suite struct ArmyTests {
    static let faces: [String?] = [
        nil, nil, nil, nil, "a", "b", "c", "b", "🐱", "🐶", "👨‍👩‍👧‍👦", "🇯🇵", "👍🏽", "✂️", "1️⃣",
        "🏳️‍🌈", "\u{200D}", "e\u{0301}", nil, "x",
    ]
    static let blank = ["", " ", "\u{00A0}", "\n", " \u{0301}"]

    @Test func anUntouchedAppFieldsTodaysArmies() {
        let frame = Screen(seed: 1).frame(seconds: 0)
        #expect(frame.armies.count == Kind.allCases.count)
        #expect(frame.armies.map(\.index) == [0, 1, 2])
        #expect(frame.armies[Int(Kind.rock.rawValue)].glyph == "🪨")
        #expect(frame.armies[Int(Kind.paper.rawValue)].glyph == "📄")
        #expect(frame.armies[Int(Kind.scissors.rawValue)].glyph == "✂️")
        #expect(frame.armies.map(\.role) == ["Rock", "Paper", "Scissors"])
        #expect(frame.armies.map(\.name) == ["Rock", "Paper", "Scissors"])
        #expect(frame.armies.map(\.soldiers) == [100, 100, 100])
        #expect(frame.armies.map(\.typedGlyph) == ["", "", ""])
        #expect(frame.armies.map(\.typedName) == ["", "", ""])
        #expect(frame.armies.map(\.glyphLabel) == ["Rock emoji", "Paper emoji", "Scissors emoji"])
        #expect(frame.armies.map(\.nameLabel) == ["Rock name", "Paper name", "Scissors name"])
        #expect(
            frame.armies.map(\.soldiersLabel)
                == ["Rock soldiers", "Paper soldiers", "Scissors soldiers"])
    }

    @Test func whatTheUserTypesComesBackExactlyAsTyped() {
        let screen = Screen(seed: 2)
        var armies = screen.frame(seconds: 0).armies
        for draft in drafts {
            for index in 0..<3 {
                for typing in [Intent.glyph(index, draft), .name(index, draft)] {
                    let now = screen.handle(typing).armies
                    for other in 0..<3 where other != index { #expect(now[other] == armies[other]) }
                    armies = now
                }
                #expect(verbatim(armies[index].typedGlyph, draft))
                #expect(verbatim(armies[index].typedName, draft))
            }
        }

        let surfaces = [
            device,
            Surface(width: 402, height: 778, unit: 3, reduceMotion: true),
            .zero,
        ]
        let cycle: [Intent] = [.newBattle, .go, .armies, .newBattle, .pause, .home]
        let asks = [refresh, 0, -1, .nan, 1e300, 10]
        let matrix = Screen(seed: 3)
        var step = 0
        for round in 0..<3 {
            for index in [-1, 0, 1, 2, 3, Int.max] {
                for (ask, draft) in zip(asks, drafts.dropFirst(round)) {
                    step += 1
                    matrix.surface = surfaces[step % surfaces.count]
                    let before = matrix.handle(cycle[step % cycle.count]).armies
                    _ = matrix.handle(.glyph(index, draft))
                    _ = matrix.handle(.name(index, draft))
                    let staged = matrix.handle(.soldiers(index, Double(Army.opening)))
                    if (0..<3).contains(index) {
                        #expect(verbatim(staged.armies[index].typedGlyph, draft))
                        #expect(verbatim(staged.armies[index].typedName, draft))
                        #expect(staged.armies[index].soldiers == Army.opening)
                        for other in 0..<3 where other != index {
                            #expect(staged.armies[other] == before[other])
                        }
                    } else {
                        #expect(staged.armies == before)
                    }
                    #expect(staged.armies.count == 3)
                    #expect(!staged.primary.title.isEmpty)
                    let elapsed = matrix.elapsed
                    let watched = staged.phase == .watching
                    _ = matrix.frame(seconds: ask)
                    if !watched { #expect(matrix.elapsed == elapsed) }
                }
            }
        }
    }

    @Test func whatFightsIsOneClusterTheUserAskedFor() {
        #expect(ArmyTests.faces.count == drafts.count)
        let screen = Screen(seed: 4)
        for (draft, face) in zip(drafts, ArmyTests.faces) {
            for index in 0..<3 {
                let glyph = screen.handle(.glyph(index, draft)).armies[index].glyph
                #expect(glyph.count == 1)
                #expect(glyph.contains { !$0.isWhitespace })
                if let face {
                    #expect(verbatim(glyph, face), "\(draft.unicodeScalars)")
                } else {
                    #expect(verbatim(glyph, Words.glyphs[index]), "\(draft.unicodeScalars)")
                }
            }
        }
    }

    @Test func aNamelessArmyIsStillNamedAndALongNameStaysWhole() {
        let screen = Screen(seed: 5)
        for draft in drafts {
            for index in 0..<3 {
                let name = screen.handle(.name(index, draft)).armies[index].name
                if ArmyTests.blank.contains(where: { verbatim($0, draft) }) {
                    #expect(verbatim(name, Words.roles[index]))
                } else {
                    #expect(verbatim(name, draft))
                }
            }
        }
        #expect(screen.handle(.name(0, String(repeating: "x", count: 500))).armies[0].name.count
            == 500)
    }

    @Test func theSliderReachesEveryArmyInTheRangeAndOnlyThose() {
        let screen = Screen(seed: 6)
        let edges: [(Double, Int)] = [
            (-1e300, 1), (-1, 1), (0, 1), (0.4, 1), (0.5, 1), (1.4, 1), (1.5, 2), (1999.6, 2000),
            (2000.4, 2000), (1e300, 2000),
        ]
        for (asked, count) in edges {
            #expect(screen.handle(.soldiers(0, asked)).armies[0].soldiers == count, "\(asked)")
        }
        for asked in [Double.infinity, -.infinity, .nan] {
            let held = screen.handle(.soldiers(0, 777)).armies[0].soldiers
            #expect(screen.handle(.soldiers(0, asked)).armies[0].soldiers == held, "\(asked)")
        }

        var reached = Set<Int>()
        var previous = 0
        var fell = false
        var misread = 0
        var furthest = 0.0
        for step in 0...19_990 {
            let asked = 1 + Double(step) / 10
            let count = screen.handle(.soldiers(1, asked)).armies[1].soldiers
            reached.insert(count)
            if count < previous { fell = true }
            if count != Int(asked.rounded()) { misread += 1 }
            furthest = max(furthest, abs(Double(count) - asked))
            previous = count
        }
        #expect(!fell)
        #expect(misread == 0)
        #expect(furthest <= 0.5)
        #expect(reached.count == Army.largest - Army.smallest + 1)
        #expect(reached.min() == Army.smallest)
        #expect(reached.max() == Army.largest)
    }

    @Test func everyChoiceTheScreenCanReachStagesARealBattle() {
        for counts in reachable {
            let screen = Screen(seed: 7)
            screen.choose(counts)
            var frame = screen.handle(.newBattle)
            let staged = try! #require(screen.battle)
            for kind in Kind.allCases {
                #expect(staged.setup[kind] == counts[Int(kind.rawValue)], "\(counts)")
            }
            #expect(frame.counts == counts)
            #expect(frame.soldiers.count == counts.reduce(0, +), "\(counts)")
            drawnInside(frame)
            _ = screen.handle(.go)
            frame = screen.frame()
            #expect(frame.soldiers.count == counts.reduce(0, +), "\(counts)")
            drawnInside(frame)
        }
    }

    private func drawnInside(_ frame: Frame) {
        let field = frame.layout.field
        let half = frame.soldierPoints / 2
        var tally = [0, 0, 0]
        var inside = true
        for dot in frame.soldiers {
            if dot.x - half < 0 || dot.x + half > field.width { inside = false }
            if dot.y - half < 0 || dot.y + half > field.height { inside = false }
            tally[dot.glyph] += 1
        }
        #expect(inside, "\(frame.counts)")
        #expect(tally == frame.counts)
    }

    @Test func noChoiceMovesAControl() {
        let untouched = Screen(seed: 8)
        var layouts: [Layout] = []
        for surface in screens {
            untouched.surface = surface
            layouts.append(untouched.frame(seconds: 0).layout)
        }
        let screen = Screen(seed: 9)
        for counts in reachable {
            screen.surface = device
            screen.choose(counts)
            for (index, surface) in screens.enumerated() {
                screen.surface = surface
                let layout = screen.frame(seconds: 0).layout
                #expect(layout == layouts[index], "\(counts) \(surface)")
                #expect(
                    screen.handle(.soldiers(0, Double(counts[0]))).layout == layouts[index],
                    "\(counts) \(surface)")
                #expect(layout.primary >= AppTests.tapTarget, "\(counts) \(surface)")
                #expect(layout.secondary >= AppTests.tapFloor, "\(counts) \(surface)")
                #expect(layout.readout > layout.body, "\(counts) \(surface)")
                #expect(layout.slot(3) >= AppTests.tapTarget, "\(counts) \(surface)")
                #expect(layout.slot(2) > layout.slot(3), "\(counts) \(surface)")
            }
        }
    }

    @Test func armiesOpensTheChooserAndPlayLeavesItOntoABattle() {
        let screen = Screen(seed: 10)
        let held = screen.handle(.newBattle)
        #expect(held.phase == .held)
        #expect(held.secondary.count == 3)
        let control = held.secondary[1]
        #expect(control.title == "ARMIES")
        #expect(control.spoken == "Armies")
        weak var staged = screen.battle
        #expect(staged != nil)

        let chooser = screen.handle(control.intent)
        #expect(staged == nil)
        #expect(chooser.phase == .choosing)
        #expect(chooser.armies.count == 3)
        #expect(chooser.primary.title == "PLAY")
        #expect(chooser.primary.intent == .newBattle)
        #expect(chooser.secondary.isEmpty)
        #expect(chooser.soldiers.isEmpty)
        #expect(chooser.counts.isEmpty)
        #expect(chooser.clock.isEmpty)
        #expect(chooser.summary.isEmpty)
        #expect(chooser.banner == nil)
        #expect(!chooser.wantsFrames)

        let left = screen.handle(chooser.primary.intent)
        #expect(left.phase == .held)
        #expect(left.counts == [100, 100, 100])
        #expect(left.soldiers.count == 300)

        let unusable = Screen(seed: 11, surface: .zero)
        #expect(unusable.handle(.armies).phase == .choosing)
        #expect(unusable.handle(.newBattle).phase == .landing)
    }

    @Test func theOpeningScreenSaysWhichArmyPlaysWhichRole() {
        let screen = Screen(seed: 12)
        #expect(
            screen.frame(seconds: 0).legend
                == "Rock plays Rock. Paper plays Paper. Scissors plays Scissors.")
        _ = screen.handle(.name(0, "Boulder"))
        _ = screen.handle(.name(1, "Boulder"))
        let renamed = screen.handle(.name(2, "Shears"))
        #expect(renamed.armies.map(\.role) == ["Rock", "Paper", "Scissors"])
        #expect(renamed.legend == "Boulder plays Rock. Boulder plays Paper. Shears plays Scissors.")
    }

    @Test func everyPlaceThatNamesAnArmyUsesTheChosenName() {
        let names = ["Boulder", "Sheet", "Shears"]
        let faces = ["🐶", "🐱", "🐭"]
        let screen = Screen(seed: 13)
        for index in 0..<3 {
            _ = screen.handle(.name(index, names[index]))
            _ = screen.handle(.glyph(index, faces[index]))
        }
        screen.choose([1, 1, 1])
        _ = screen.handle(.newBattle)
        _ = screen.handle(.go)
        let frame = screen.runToEnd(within: 5_000)
        #expect(frame.phase == .finished)
        #expect(frame.armies.map(\.glyph) == faces)
        #expect(frame.armies.map(\.name) == names)
        let winner = try! #require(frame.counts.firstIndex(of: 3))
        let banner = try! #require(frame.banner)
        #expect(banner.winner == "\(faces[winner]) wins!")
        #expect(banner.spoken == "\(names[winner]) wins after \(frame.clock) seconds")
        for index in 0..<3 {
            #expect(frame.summary.contains("\(names[index]) \(frame.counts[index])"))
        }
        for role in Words.roles {
            #expect(!frame.summary.contains(role))
            #expect(!banner.spoken.contains(role))
            #expect(!banner.winner.contains(role))
        }
    }

    @Test func theAppOpensWithWhatWasLastChosen() {
        let first = Screen(seed: 14)
        _ = first.handle(.glyph(0, "🐶 "))
        _ = first.handle(.name(1, "Sheet"))
        _ = first.handle(.soldiers(2, 777))
        let chosen = first.frame(seconds: 0)
        let opened = Screen(seed: 15, record: chosen.record).frame(seconds: 0)
        #expect(opened.phase == .landing)
        #expect(opened.armies == chosen.armies)
        #expect(opened.armies.map(\.glyph) == chosen.armies.map(\.glyph))
        #expect(opened.armies.map(\.name) == chosen.armies.map(\.name))
        #expect(opened.armies.map(\.soldiers) == [100, 100, 777])
        #expect(zip(opened.record, chosen.record).allSatisfy(verbatim))
    }

    @Test func aRecordTheAppDidNotWriteIsStillAnApp() {
        let long = String(repeating: "9", count: 40)
        let records: [([String], [String], [String], [Int])] = [
            ([], ["🪨", "📄", "✂️"], ["Rock", "Paper", "Scissors"], [100, 100, 100]),
            (
                Array(repeating: "x", count: 8), ["🪨", "📄", "✂️"], ["Rock", "Paper", "Scissors"],
                [100, 100, 100]
            ),
            (
                Array(repeating: "x", count: 10), ["🪨", "📄", "✂️"], ["Rock", "Paper", "Scissors"],
                [100, 100, 100]
            ),
            (
                Array(repeating: "", count: 9), ["🪨", "📄", "✂️"], ["Rock", "Paper", "Scissors"],
                [100, 100, 100]
            ),
            (
                ["", "", "abc", "", "", "0", "", "", "-3"], ["🪨", "📄", "✂️"],
                ["Rock", "Paper", "Scissors"], [100, 1, 1]
            ),
            (
                ["", "", "2001", "", "", "1e3", "", "", " 5"], ["🪨", "📄", "✂️"],
                ["Rock", "Paper", "Scissors"], [2000, 100, 100]
            ),
            (
                ["", "", long, "", "", "2000", "", "", "1"], ["🪨", "📄", "✂️"],
                ["Rock", "Paper", "Scissors"], [100, 2000, 1]
            ),
            (
                ["🐶🐱", "🐶 ", "100", "👨‍👩‍👧‍👦", "\u{00A0}", "100", "🇯🇵", "e\u{0301}", "100"],
                ["🐱", "👨‍👩‍👧‍👦", "🇯🇵"], ["🐶 ", "Paper", "e\u{0301}"], [100, 100, 100]
            ),
        ]
        for (index, (record, glyphs, names, counts)) in records.enumerated() {
            let screen = Screen(seed: UInt64(20 + index), record: record)
            let opened = screen.frame(seconds: 0)
            #expect(opened.armies.map(\.glyph) == glyphs, "\(record)")
            #expect(opened.armies.map(\.name) == names, "\(record)")
            #expect(opened.armies.map(\.soldiers) == counts, "\(record)")
            let staged = screen.handle(.newBattle)
            #expect(staged.counts == counts, "\(record)")
            #expect(staged.soldiers.count == counts.reduce(0, +), "\(record)")
        }
    }

    @Test func theRecordSaysExactlyWhatIsRemembered() {
        let screen = Screen(seed: 16)
        _ = screen.handle(.glyph(0, "🐶 "))
        _ = screen.handle(.name(1, "Sheet"))
        screen.choose([1, 1, 1])
        let record = screen.frame(seconds: 0).record
        #expect(record == ["🐶 ", "", "1", "", "Sheet", "1", "", "", "1"])
        #expect(zip(record, ["🐶 ", "", "1", "", "Sheet", "1", "", "", "1"]).allSatisfy(verbatim))
        #expect(Frame.opening.record == ["", "", "100", "", "", "100", "", "", "100"])
        #expect(Screen(seed: 17, record: record).frame(seconds: 0).record == record)

        #expect(screen.handle(.newBattle).record == record)
        _ = screen.handle(.go)
        var moved = true
        let watched = screen.run(5) { moved = moved && $0.record == record }
        #expect(moved)
        #expect(watched.record == record)
        #expect(screen.handle(.pause).record == record)
        _ = screen.handle(.go)
        var fought = true
        let ended = screen.runToEnd(within: 5_000) { fought = fought && $0.record == record }
        #expect(fought)
        #expect(ended.phase == .finished)
        var celebrated = true
        let party = screen.run(60) { celebrated = celebrated && $0.record == record }
        #expect(celebrated)
        #expect(party.record == record)
        #expect(screen.handle(.home).record == record)
    }

    @Test func theChooserSurvivesTheKeyboard() {
        for surface in screens {
            let shortened = Surface(
                width: surface.width, height: surface.height - 400, unit: surface.unit,
                reduceMotion: surface.reduceMotion)
            let screen = Screen(seed: 18, surface: shortened)
            let chooser = screen.handle(.armies)
            #expect(chooser.phase == .choosing)
            let layout = chooser.layout
            #expect(layout != Layout.zero, "\(shortened)")
            #expect(layout.primary >= AppTests.tapTarget, "\(shortened)")
            #expect(layout.secondary >= AppTests.tapFloor, "\(shortened)")
            #expect(layout.slot(3) >= AppTests.tapTarget, "\(shortened)")
            let staged = screen.handle(.newBattle)
            #expect(staged.phase == .held, "\(shortened)")
            #expect(staged.soldiers.count == 300, "\(shortened)")
        }
    }
}
