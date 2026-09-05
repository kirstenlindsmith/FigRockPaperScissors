import BattleEngine
import BattleFixtures

@testable import BattleApp

let device = Surface(width: 402, height: 778, unit: 1, reduceMotion: false)
let refresh = 1.0 / 60
let pinned: UInt64 = 39
let screens = [320.0, 360, 375, 390, 402, 430, 440].flatMap { width in
    [600.0, 778, 900].flatMap { height in
        [0.5, 1.0, 1.6, 2.09, 3.1, 12.0, 1e9].map {
            Surface(width: width, height: height, unit: $0, reduceMotion: false)
        }
    }
}

let drafts = [
    "", " ", "\u{00A0}", "\n", "a", "ab", "abc ", " ab ", "🐶🐱", "🐶 ", "👨‍👩‍👧‍👦", "🇯🇵", "👍🏽", "✂️", "1️⃣",
    "🏳️‍🌈", "\u{200D}", "e\u{0301}", " \u{0301}", String(repeating: "x", count: 500),
]

let reachable = [
    [100, 100, 100],
    [1, 1, 1],
    [2000, 2000, 2000],
    [2000, 1, 1],
    [1, 2000, 1],
    [1, 1, 2000],
    [2000, 2000, 1],
    [777, 13, 1],
]

func spots(_ soldiers: [Dot]) -> [SIMD2<Double>] { soldiers.map { SIMD2($0.x, $0.y) } }

func bunched(_ spots: [SIMD2<Double>], into field: Size) -> [SIMD2<Double>] {
    spots.map {
        SIMD2(
            field.width / 2 + ($0.x - field.width / 2) / 4,
            field.height / 2 + ($0.y - field.height / 2) / 4
        )
    }
}

func coverage(of spots: [SIMD2<Double>], over field: Size) -> Coverage {
    Coverage(spots: spots, over: SIMD2(field.width, field.height))
}

func sharedSpots(_ one: [Dot], _ other: [Dot]) -> Int {
    one.count { dot in other.contains { $0.x == dot.x && $0.y == dot.y } }
}

final class Screen {
    let director: Director
    var surface: Surface

    init(seed: UInt64, record: [String] = [], surface: Surface = device) {
        director = Director(seed: seed, record: record)
        self.surface = surface
    }

    var battle: Battle? { director.battle }
    var elapsed: Double { battle.map { Clock.seconds($0.elapsed) } ?? 0 }

    func handle(_ intent: Intent) -> Frame { director.handle(intent, surface: surface) }

    func choose(_ counts: [Int]) {
        for index in counts.indices { _ = handle(.soldiers(index, Double(counts[index]))) }
    }

    func frame(seconds: Double = refresh) -> Frame {
        director.frame(surface: surface, seconds: seconds)
    }

    func run(_ frames: Int) -> Frame {
        var last = frame(seconds: 0)
        for _ in 0..<frames { last = frame() }
        return last
    }

    func runToEnd(within frames: Int) -> Frame {
        var last = frame(seconds: 0)
        var left = frames
        while last.phase != .finished && left > 0 {
            last = frame()
            left -= 1
        }
        return last
    }
}
