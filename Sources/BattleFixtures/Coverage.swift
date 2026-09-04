import BattleEngine

public struct Coverage: Sendable {
    public static let soldiersPerBlock = 20

    public let across: Int
    public let down: Int
    public let expected: Double
    public let emptyBlocks: Int
    public let worstBlockNoises: Double

    public init(spots: [SIMD2<Double>], over field: SIMD2<Double>) {
        let wanted = max(1, spots.count / Coverage.soldiersPerBlock)
        let shape = (Double(wanted) * field.x / field.y).squareRoot().rounded()
        let columns = min(wanted, max(1, Int(shape)))
        let rows = max(1, wanted / columns)
        var held = [Int](repeating: 0, count: columns * rows)
        for spot in spots {
            let i = min(columns - 1, max(0, Int(spot.x / field.x * Double(columns))))
            let j = min(rows - 1, max(0, Int(spot.y / field.y * Double(rows))))
            held[j * columns + i] += 1
        }
        let share = Double(spots.count) / Double(columns * rows)
        across = columns
        down = rows
        expected = share
        emptyBlocks = held.count { $0 == 0 }
        worstBlockNoises = held.reduce(0.0) {
            max($0, abs(Double($1) - share) / share.squareRoot())
        }
    }

    public init(_ battle: Battle) {
        let arena = battle.setup.arena
        self.init(
            spots: battle.withSoldiers { positions, _ in
                positions.map { SIMD2(Double($0.x), Double($0.y)) }
            },
            over: SIMD2(Double(arena.x), Double(arena.y))
        )
    }
}
