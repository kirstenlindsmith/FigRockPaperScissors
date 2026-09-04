public enum Phase: Equatable, Sendable { case landing, held, watching, finished }

public enum Speed: Int, CaseIterable, Equatable, Sendable {
    case normal = 1, double = 2, quintuple = 5
}

public enum Intent: Equatable, Sendable {
    case newBattle, go, pause, home
    case speed(Speed)
}

public struct Dot: Equatable, Sendable {
    public let glyph: Int
    public let x: Double
    public let y: Double

    init(glyph: Int, x: Double, y: Double) {
        self.glyph = glyph
        self.x = x
        self.y = y
    }
}

public struct Control: Equatable, Sendable {
    public let title: String
    public let spoken: String
    public let intent: Intent
    public let selected: Bool
}

public struct Banner: Equatable, Sendable {
    public let winner: String
    public let duration: String
    public let spoken: String
}

public struct Frame: Equatable, Sendable {
    public let phase: Phase
    public let layout: Layout
    public let soldiers: [Dot]
    public let soldierPoints: Double
    public let confetti: [Dot]
    public let confettiPoints: Double
    public let counts: [Int]
    public let clock: String
    public let banner: Banner?
    public let summary: String
    public let primary: Control
    public let secondary: [Control]
    public let wantsFrames: Bool

    public static let opening = Director(seed: 0).frame(surface: .zero, seconds: 0)
}
