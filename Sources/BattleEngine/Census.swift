public struct Census: Sendable, Equatable {
    var rock: Int
    var paper: Int
    var scissors: Int

    init(rock: Int, paper: Int, scissors: Int) {
        self.rock = rock
        self.paper = paper
        self.scissors = scissors
    }

    public subscript(kind: Kind) -> Int {
        switch kind {
        case .rock: rock
        case .paper: paper
        case .scissors: scissors
        }
    }

    public var total: Int { rock + paper + scissors }

    public var victor: Kind? {
        var found: Kind?
        for kind in Kind.allCases where self[kind] > 0 {
            if found != nil { return nil }
            found = kind
        }
        return found
    }

    public var isOver: Bool {
        var live = 0
        for kind in Kind.allCases where self[kind] > 0 { live += 1 }
        return live <= 1
    }
}
