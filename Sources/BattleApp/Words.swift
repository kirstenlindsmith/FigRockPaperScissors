public enum Words {
    public static let glyphs = ["\u{1FAA8}", "\u{1F4C4}", "\u{2702}\u{FE0F}"]
    public static let names = ["Rock", "Paper", "Scissors"]
}

extension Words {
    static let play = Control(title: "PLAY", spoken: "Play", intent: .newBattle, selected: false)
    static let go = Control(title: "GO", spoken: "Go", intent: .go, selected: false)
    static let resume = Control(title: "RESUME", spoken: "Resume", intent: .go, selected: false)
    static let pause = Control(title: "PAUSE", spoken: "Pause", intent: .pause, selected: false)
    static let again = Control(
        title: "PLAY AGAIN", spoken: "Play again", intent: .newBattle, selected: false)
    static let over = Control(
        title: "START OVER", spoken: "Start over", intent: .newBattle, selected: false)
    static let home = Control(title: "HOME", spoken: "Home", intent: .home, selected: false)

    static func primary(phase: Phase, started: Bool) -> Control {
        switch phase {
        case .landing: play
        case .held: started ? resume : go
        case .watching: pause
        case .finished: again
        }
    }

    static func pace(_ speed: Speed) -> String {
        switch speed {
        case .normal: "Normal"
        case .double: "Double"
        case .quintuple: "Five times"
        }
    }

    static func secondary(phase: Phase, speed: Speed) -> [Control] {
        switch phase {
        case .landing: []
        case .held: [over, home]
        case .watching: Speed.allCases.map {
            Control(
                title: "\($0.rawValue)\u{00D7}", spoken: "\(pace($0)) speed", intent: .speed($0),
                selected: speed == $0)
        }
        case .finished: [home]
        }
    }
}
