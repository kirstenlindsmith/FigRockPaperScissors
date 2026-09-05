struct Tuning {
    static let ticksPerSecond = 64
    static let tickAttoseconds = 1_000_000_000_000_000_000 / ticksPerSecond
    static let tick = Duration(secondsComponent: 0, attosecondsComponent: Int64(tickAttoseconds))
    static let tickSeconds: Float = 1 / Float(ticksPerSecond)
    static let longestDelivery = Duration.seconds(Int64.max)

    static let chaseSpeedInSpacings: Float = 8
    static let fleeFraction: Float = 0.6
    static let contactInSpacings: Float = 0.5
    static let bodyInContacts: Float = 0.9
    static let displacementCapInSteps: Float = 2.4
    static let interactionInSteps: Float = 2

    static let candidateCap = 48
    static let firstRingRows = 3
    static let constraintPasses = 4
    static let pushPasses = 4
    static let exactReachRings = 6
    static let fieldCellInGridCells = 2
    static let fieldBlockRadius = 1
    static let maxCellsPerSoldier = 4

    static let latticeSitesPerSoldierCeiling = 5
    static let latticeStepGuard = 64
    static let jitterOfSlack: Float = 0.45

    static let arenaLengthInBodies: Float = 65536
    static let coincidenceSquared: Float = 1e-20

    static let largestArmy = Int(Int32.max) / (Kind.allCases.count * maxCellsPerSoldier)
    static let largestField = largestArmy * Kind.allCases.count

    static func aspect(from value: Float) -> Float { value.isFinite && value > 0 ? value : 1 }

    let soldiers: Int
    let spacing: Float
    let contact: Float
    let body: Float
    let chaseStep: Float
    let fleeStep: Float
    let displacementCap: Float
    let interaction: Float

    init(soldiers count: Int) {
        let n = max(1, count)
        soldiers = n
        spacing = 1 / Float(n).squareRoot()
        contact = Tuning.contactInSpacings * spacing
        body = Tuning.bodyInContacts * contact
        let step = Tuning.chaseSpeedInSpacings * spacing * Tuning.tickSeconds
        chaseStep = step
        fleeStep = Tuning.fleeFraction * step
        displacementCap = Tuning.displacementCapInSteps * step
        interaction = body + Tuning.interactionInSteps * step
    }

    var arenaShortSideFloor: Float {
        min(1, max(2 * body, (1 / Tuning.arenaLengthInBodies) / body))
    }

    func arena(aspect: Float) -> SIMD2<Float> {
        let floor = arenaShortSideFloor
        let widest = 1 / (floor * floor)
        let a = min(max(Tuning.aspect(from: aspect), 1 / widest), widest)
        let w = a.squareRoot()
        return SIMD2(w, 1 / w)
    }
}
