public enum Kind: UInt8, Sendable, Codable, CaseIterable {
    case rock, paper, scissors

    public static let allCases: [Kind] = [.rock, .paper, .scissors]
}

extension Kind {
    public var beats: Kind {
        switch self {
        case .rock: .scissors
        case .paper: .rock
        case .scissors: .paper
        }
    }

    var beatenBy: Kind {
        switch self {
        case .rock: .paper
        case .paper: .scissors
        case .scissors: .rock
        }
    }

    var index: Int { Int(rawValue) }
}
