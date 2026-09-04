public struct Setup: Sendable, Equatable, Codable {
    private var storedAspect: Float
    private var storedRock: Int
    private var storedPaper: Int
    private var storedScissors: Int

    public var aspect: Float {
        get { storedAspect }
        set { storedAspect = Setup.aspect(from: newValue) }
    }

    public var seed: UInt64

    public var rock: Int {
        get { storedRock }
        set { storedRock = Setup.count(from: newValue) }
    }

    public var paper: Int {
        get { storedPaper }
        set { storedPaper = Setup.count(from: newValue) }
    }

    public var scissors: Int {
        get { storedScissors }
        set { storedScissors = Setup.count(from: newValue) }
    }

    public init(aspect: Float, seed: UInt64, rock: Int, paper: Int, scissors: Int) {
        storedAspect = Setup.aspect(from: aspect)
        self.seed = seed
        storedRock = Setup.count(from: rock)
        storedPaper = Setup.count(from: paper)
        storedScissors = Setup.count(from: scissors)
    }

    public subscript(kind: Kind) -> Int {
        get {
            switch kind {
            case .rock: storedRock
            case .paper: storedPaper
            case .scissors: storedScissors
            }
        }
        set {
            switch kind {
            case .rock: rock = newValue
            case .paper: paper = newValue
            case .scissors: scissors = newValue
            }
        }
    }

    public var count: Int { storedRock + storedPaper + storedScissors }

    public var arena: SIMD2<Float> { Tuning(soldiers: count).arena(aspect: storedAspect) }

    public var soldierDiameter: Float { Tuning(soldiers: count).contact }

    public var storageBytes: Int {
        let tuning = Tuning(soldiers: count)
        return Storage(tuning: tuning, arena: tuning.arena(aspect: storedAspect)).bytes
    }

    private static func aspect(from value: Float) -> Float {
        value.isFinite && value > 0 ? value : 1
    }

    private static func count(from value: Int) -> Int { min(max(0, value), Tuning.largestArmy) }

    private enum CodingKeys: String, CodingKey { case aspect, seed, rock, paper, scissors }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        storedAspect = Setup.aspect(from: try box.decode(Float.self, forKey: .aspect))
        seed = try box.decode(UInt64.self, forKey: .seed)
        storedRock = Setup.count(from: try box.decode(Int.self, forKey: .rock))
        storedPaper = Setup.count(from: try box.decode(Int.self, forKey: .paper))
        storedScissors = Setup.count(from: try box.decode(Int.self, forKey: .scissors))
    }

    public func encode(to encoder: any Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(storedAspect, forKey: .aspect)
        try box.encode(seed, forKey: .seed)
        try box.encode(storedRock, forKey: .rock)
        try box.encode(storedPaper, forKey: .paper)
        try box.encode(storedScissors, forKey: .scissors)
    }
}
