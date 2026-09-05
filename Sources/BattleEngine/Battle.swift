public final class Battle {
    let tuning: Tuning
    public let arena: SIMD2<Float>
    let soldiers: Int

    let gridWidth: Int
    let gridHeight: Int
    let cells: Int
    let cellSize: SIMD2<Float>

    let fieldWidth: Int
    let fieldHeight: Int
    let fieldCells: Int
    let fieldCellSize: SIMD2<Float>

    var positions: UnsafeMutablePointer<SIMD2<Float>>
    var positionsNext: UnsafeMutablePointer<SIMD2<Float>>
    var kinds: UnsafeMutablePointer<Kind>
    var kindsNext: UnsafeMutablePointer<Kind>

    var mirrorPosition: UnsafeMutablePointer<SIMD2<Float>>
    var mirrorKind: UnsafeMutablePointer<Kind>
    var mirrorIndex: UnsafeMutablePointer<Int32>

    let cellStart: UnsafeMutablePointer<Int32>
    let cellCursor: UnsafeMutablePointer<Int32>
    let cellKinds: UnsafeMutablePointer<UInt8>
    let cellOf: UnsafeMutablePointer<Int32>

    let fieldPosition: UnsafeMutablePointer<SIMD2<Float>>
    let fieldSeedDistance: UnsafeMutablePointer<Float>

    let neighbourDelta: UnsafeMutablePointer<SIMD2<Float>>
    let neighbourDistance: UnsafeMutablePointer<Float>
    let neighbourIndex: UnsafeMutablePointer<Int32>
    let neighbourCapacity: Int

    var latticeSites = 0
    var latticeSpacing = SIMD2<Float>.zero

    var counts: (rock: Int, paper: Int, scissors: Int) = (0, 0, 0)
    var ticksRun = 0
    var unspent: Int128 = 0

    let kernel: Kernel
    var candidateVisits = 0
    var worstSoldierVisits = 0
    var worstRowLength = 0

    public convenience init(_ setup: Setup) {
        self.init(setup, kernel: Kernel())
    }

    public convenience init(placing soldiers: [(SIMD2<Float>, Kind)], aspect: Float) {
        self.init(placing: soldiers, aspect: aspect, kernel: Kernel())
    }

    convenience init(_ setup: Setup, kernel: Kernel) {
        self.init(aspect: setup.aspect, soldiers: setup.count, kernel: kernel)
        place(setup)
        recount()
    }

    convenience init(placing given: [(SIMD2<Float>, Kind)], aspect: Float, kernel: Kernel) {
        self.init(aspect: aspect, soldiers: given.count, kernel: kernel)
        let room = standingRoom
        for i in 0..<soldiers {
            positions[i] = given[i].0.clamped(lowerBound: room.low, upperBound: room.high)
            kinds[i] = given[i].1
        }
        recount()
    }

    init(aspect: Float, soldiers count: Int, kernel: Kernel) {
        self.kernel = kernel
        let n = min(count, Tuning.largestField)
        soldiers = n
        tuning = Tuning(soldiers: n)
        arena = tuning.arena(aspect: aspect)

        let storage = Storage(tuning: tuning, arena: arena)
        gridWidth = storage.gridWidth
        gridHeight = storage.gridHeight
        cells = storage.cells
        cellSize = storage.cellSize
        fieldWidth = storage.fieldWidth
        fieldHeight = storage.fieldHeight
        fieldCells = storage.fieldCells
        fieldCellSize = storage.fieldCellSize
        neighbourCapacity = storage.neighbourCapacity

        positions = storage.positions.allocate(.zero)
        positionsNext = storage.positionsNext.allocate(.zero)
        kinds = storage.kinds.allocate(.rock)
        kindsNext = storage.kindsNext.allocate(.rock)
        mirrorPosition = storage.mirrorPosition.allocate(.zero)
        mirrorKind = storage.mirrorKind.allocate(.rock)
        mirrorIndex = storage.mirrorIndex.allocate(0)
        cellOf = storage.cellOf.allocate(0)
        cellStart = storage.cellStart.allocate(0)
        cellCursor = storage.cellCursor.allocate(0)
        cellKinds = storage.cellKinds.allocate(0)
        fieldPosition = storage.fieldPosition.allocate(.zero)
        fieldSeedDistance = storage.fieldSeedDistance.allocate(0)
        neighbourDelta = storage.neighbourDelta.allocate(.zero)
        neighbourDistance = storage.neighbourDistance.allocate(0)
        neighbourIndex = storage.neighbourIndex.allocate(0)
    }

    var standingRoom: (low: SIMD2<Float>, high: SIMD2<Float>) {
        let inset = SIMD2<Float>(repeating: tuning.body * 0.5)
        return (inset, arena - inset)
    }

    public var soldierDiameter: Float { tuning.contact }

    deinit {
        positions.deallocate()
        positionsNext.deallocate()
        kinds.deallocate()
        kindsNext.deallocate()
        mirrorPosition.deallocate()
        mirrorKind.deallocate()
        mirrorIndex.deallocate()
        cellOf.deallocate()
        cellStart.deallocate()
        cellCursor.deallocate()
        cellKinds.deallocate()
        fieldPosition.deallocate()
        fieldSeedDistance.deallocate()
        neighbourDelta.deallocate()
        neighbourDistance.deallocate()
        neighbourIndex.deallocate()
    }

    public func advance(by battleTime: Duration) {
        guard !census.isOver else { return }
        let parts = min(max(.zero, battleTime), Tuning.longestDelivery).components
        unspent += Int128(parts.seconds) * 1_000_000_000_000_000_000 + Int128(parts.attoseconds)
        let tick = Int128(Tuning.tickAttoseconds)
        while unspent >= tick {
            if census.isOver { return }
            step()
            unspent -= tick
        }
    }

    public var elapsed: Duration {
        Duration(
            secondsComponent: Int64(ticksRun / Tuning.ticksPerSecond),
            attosecondsComponent: Int64(ticksRun % Tuning.ticksPerSecond)
                * Int64(Tuning.tickAttoseconds)
        )
    }

    public var census: Census {
        Census(rock: counts.rock, paper: counts.paper, scissors: counts.scissors)
    }

    public func withSoldiers<R>(
        _ body: (UnsafeBufferPointer<SIMD2<Float>>, UnsafeBufferPointer<Kind>) throws -> R
    ) rethrows -> R {
        try body(
            UnsafeBufferPointer(start: positions, count: soldiers),
            UnsafeBufferPointer(start: kinds, count: soldiers)
        )
    }

    func recount() {
        var rock = 0, paper = 0, scissors = 0
        for i in 0..<soldiers {
            switch kinds[i] {
            case .rock: rock += 1
            case .paper: paper += 1
            case .scissors: scissors += 1
            }
        }
        counts = (rock, paper, scissors)
    }
}

struct Kernel {
    var exactReachRings = Tuning.exactReachRings
    var constraintPasses = Tuning.constraintPasses
    var pushPasses = Tuning.pushPasses
    var fieldEnabled = true
    var shuffledFill = true
}
