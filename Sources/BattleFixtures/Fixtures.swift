import BattleEngine

public enum Armies: String, CaseIterable, Sendable {
    case even, lopsided
}

public enum Fixtures {
    public static let phoneAspect: Float = 19.5 / 9.0

    public static func setup(
        _ armies: Armies,
        soldiers: Int,
        seed: UInt64,
        aspect: Float = phoneAspect
    ) -> Setup {
        let counts = counts(armies, soldiers: soldiers)
        return Setup(
            aspect: aspect,
            seed: seed,
            rock: counts[0],
            paper: counts[1],
            scissors: counts[2]
        )
    }

    public static func counts(_ armies: Armies, soldiers n: Int) -> [Int] {
        armies == .lopsided ? [n - 2 * (n / 10), n / 10, n / 10] : [n / 3, n / 3, n - 2 * (n / 3)]
    }
}
