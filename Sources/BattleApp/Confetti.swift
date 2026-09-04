enum Confetti {
    static let pieces = 48
    static let fall = 2.2
    static let stagger = 0.8
    static let span = fall + stagger
    static let sway = 0.6
    static let lane = 0.618_033_988_749_894_9
    static let launch = 0.754_877_666_246_692_7
    static let wave = 0.569_840_290_998_053_2

    static func fraction(_ value: Double) -> Double { value - value.rounded(.down) }

    static func triangle(_ phase: Double) -> Double { 4 * (fraction(phase) - 0.5).magnitude - 1 }

    static func piece(_ index: Int, glyph: Int, seconds: Double, field: Size, points: Double) -> Dot? {
        let i = Double(index)
        let life = seconds - fraction(i * launch) * stagger
        guard life <= fall, points > 0, field.width > 2 * points else { return nil }
        let column = fraction(i * lane)
        let drift = points / 2 * triangle(fraction(i * wave) + life / sway)
        return Dot(
            glyph: glyph,
            x: points + column * (field.width - 2 * points) + drift,
            y: -points + life / fall * (field.height + 2 * points))
    }

    static func dots(
        glyph: Int, seconds: Double, field: Size, points: Double, reduceMotion: Bool
    ) -> [Dot] {
        guard !reduceMotion else { return [] }
        var falling: [Dot] = []
        falling.reserveCapacity(pieces)
        for index in 0..<pieces {
            if let dot = piece(index, glyph: glyph, seconds: seconds, field: field, points: points) {
                falling.append(dot)
            }
        }
        return falling
    }
}
