public struct Layout: Equatable, Sendable {
    static let readoutUnits = 44.0
    static let secondaryUnits = 56.0
    static let primaryUnits = 88.0
    static let gapUnits = 8.0
    static let padUnits = 4.0
    static let bodyUnits = 28.0
    static let titleUnits = 44.0
    static let chromeUnits =
        readoutUnits + secondaryUnits + primaryUnits + 3 * gapUnits + 2 * padUnits
    static let smallestUnit = 0.5
    static let legibleInk = 10.0
    static let artInShortSide = 5.0

    public let unit: Double
    public let readout: Double
    public let secondary: Double
    public let primary: Double
    public let gap: Double
    public let pad: Double
    public let body: Double
    public let title: Double
    public let art: Double
    public let field: Size

    static let zero = Layout()

    private init() {
        unit = 0
        readout = 0
        secondary = 0
        primary = 0
        gap = 0
        pad = 0
        body = 0
        title = 0
        art = 0
        field = .zero
    }

    init(_ surface: Surface, diameter: Double) {
        let width = surface.width.isFinite && surface.width > 0 ? surface.width : 0
        let height = surface.height.isFinite && surface.height > 0 ? surface.height : 0
        let asked = surface.unit.isFinite ? max(surface.unit, Layout.smallestUnit) : 1
        let ceiling =
            (height - Layout.legibleHeight(width: width, diameter: diameter)) / Layout.chromeUnits
        let u = max(min(asked, ceiling), Layout.smallestUnit)
        let remaining = height - u * Layout.chromeUnits
        guard width > 0, remaining > 0 else {
            self = .zero
            return
        }
        unit = u
        readout = u * Layout.readoutUnits
        secondary = u * Layout.secondaryUnits
        primary = u * Layout.primaryUnits
        gap = u * Layout.gapUnits
        pad = u * Layout.padUnits
        body = u * Layout.bodyUnits
        title = u * Layout.titleUnits
        art = min(width, remaining) / Layout.artInShortSide
        field = Size(width: width, height: remaining)
    }

    public func slot(_ controls: Int) -> Double {
        (field.width - Double(controls + 1) * gap) / Double(controls)
    }

    static func legibleHeight(width: Double, diameter: Double) -> Double {
        guard width > legibleInk, diameter > 0 else { return 0 }
        let widthBinds = diameter * (width - legibleInk) / legibleInk
        let root = (legibleInk * legibleInk + 4 * diameter * diameter * width * legibleInk)
            .squareRoot()
        let heightBinds = (legibleInk + root) / (2 * diameter * width)
        return max(width / (widthBinds * widthBinds), width * heightBinds * heightBinds)
            .rounded(.up)
    }
}
