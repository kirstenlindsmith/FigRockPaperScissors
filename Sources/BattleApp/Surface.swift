public struct Size: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = Size(width: 0, height: 0)
}

public struct Surface: Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var unit: Double
    public var reduceMotion: Bool

    public init(width: Double, height: Double, unit: Double, reduceMotion: Bool) {
        self.width = width
        self.height = height
        self.unit = unit
        self.reduceMotion = reduceMotion
    }

    public static let zero = Surface(width: 0, height: 0, unit: 1, reduceMotion: false)
}
