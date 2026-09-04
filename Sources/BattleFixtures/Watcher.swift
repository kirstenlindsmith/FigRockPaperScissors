@_spi(Instrumentation) import BattleEngine

public struct Watcher {
    public static let surgeShareOfArmy = 0.05
    public static let censusEvery = 8

    private let battle: Battle
    private var kinds: [Kind]
    private var series: [[Int]] = []
    public private(set) var conversions = 0
    public private(set) var kindTicks = 0

    public init(_ battle: Battle) {
        self.battle = battle
        kinds = battle.withSoldiers { _, k in Array(k) }
    }

    public mutating func observe() {
        battle.withSoldiers { _, now in
            for i in 0..<now.count where now[i] != kinds[i] {
                conversions += 1
                kinds[i] = now[i]
            }
        }
        kindTicks += kinds.count
        if battle.tickCount % Watcher.censusEvery == 0 {
            let census = battle.census
            series.append(Kind.allCases.map { census[$0] })
        }
    }

    public var handChangesPerSoldier: Double {
        Double(conversions) / Double(max(1, battle.setup.count))
    }

    public var meanKindLifetimeInSeconds: Double {
        Double(kindTicks) / Double(max(1, conversions)) / 64
    }

    public var surges: Int {
        let threshold = Double(max(1, battle.setup.count)) * Watcher.surgeShareOfArmy
        var count = 0
        guard let first = series.first else { return 0 }
        for k in 0..<3 {
            var trough = Double(first[k])
            var peak = trough
            var rising = true
            for point in series {
                let value = Double(point[k])
                if rising {
                    if value > peak { peak = value }
                    if peak - value > threshold && peak - trough > threshold {
                        count += 1
                        rising = false
                        trough = value
                    }
                } else {
                    if value < trough { trough = value }
                    if value - trough > threshold {
                        rising = true
                        peak = value
                    }
                }
            }
        }
        return count
    }
}
