struct Slot<T> {
    let count: Int

    func allocate(_ initial: T) -> UnsafeMutablePointer<T> {
        let buffer = UnsafeMutablePointer<T>.allocate(capacity: count)
        buffer.initialize(repeating: initial, count: count)
        return buffer
    }
}

struct Plan {
    private(set) var bytes = 0

    mutating func take<T>(_ count: Int) -> Slot<T> {
        bytes += count * MemoryLayout<T>.stride
        return Slot(count: count)
    }
}

struct Storage {
    let gridWidth: Int
    let gridHeight: Int
    let cells: Int
    let cellSize: SIMD2<Float>
    let fieldWidth: Int
    let fieldHeight: Int
    let fieldCells: Int
    let fieldCellSize: SIMD2<Float>
    let neighbourCapacity: Int

    let positions: Slot<SIMD2<Float>>
    let positionsNext: Slot<SIMD2<Float>>
    let kinds: Slot<Kind>
    let kindsNext: Slot<Kind>
    let mirrorPosition: Slot<SIMD2<Float>>
    let mirrorKind: Slot<Kind>
    let mirrorIndex: Slot<Int32>
    let cellOf: Slot<Int32>
    let cellStart: Slot<Int32>
    let cellCursor: Slot<Int32>
    let cellKinds: Slot<UInt8>
    let fieldPosition: Slot<SIMD2<Float>>
    let fieldSeedDistance: Slot<Float>
    let neighbourDelta: Slot<SIMD2<Float>>
    let neighbourDistance: Slot<Float>
    let neighbourIndex: Slot<Int32>
    let bytes: Int

    init(tuning: Tuning, arena: SIMD2<Float>) {
        var side = tuning.interaction
        var gx = max(1, Int(arena.x / side))
        var gy = max(1, Int(arena.y / side))
        while gx * gy > Tuning.maxCellsPerSoldier * tuning.soldiers {
            side *= 2
            gx = max(1, Int(arena.x / side))
            gy = max(1, Int(arena.y / side))
        }
        gridWidth = gx
        gridHeight = gy
        cells = gx * gy
        cellSize = SIMD2(arena.x / Float(gx), arena.y / Float(gy))

        let span = Tuning.fieldCellInGridCells
        let fx = max(1, (gx + span - 1) / span)
        let fy = max(1, (gy + span - 1) / span)
        fieldWidth = fx
        fieldHeight = fy
        fieldCells = fx * fy
        fieldCellSize = SIMD2(arena.x / Float(fx), arena.y / Float(fy))

        neighbourCapacity = Tuning.firstRingRows * Tuning.candidateCap

        let soldierSlots = max(1, tuning.soldiers)
        let cellSlots = cells + 1
        let fieldSlots = Kind.allCases.count * fieldCells

        var plan = Plan()
        positions = plan.take(soldierSlots)
        positionsNext = plan.take(soldierSlots)
        kinds = plan.take(soldierSlots)
        kindsNext = plan.take(soldierSlots)
        mirrorPosition = plan.take(soldierSlots)
        mirrorKind = plan.take(soldierSlots)
        mirrorIndex = plan.take(soldierSlots)
        cellOf = plan.take(soldierSlots)
        cellStart = plan.take(cellSlots)
        cellCursor = plan.take(cellSlots)
        cellKinds = plan.take(cellSlots)
        fieldPosition = plan.take(fieldSlots)
        fieldSeedDistance = plan.take(fieldSlots)
        neighbourDelta = plan.take(neighbourCapacity)
        neighbourDistance = plan.take(neighbourCapacity)
        neighbourIndex = plan.take(neighbourCapacity)
        bytes = plan.bytes
    }
}
