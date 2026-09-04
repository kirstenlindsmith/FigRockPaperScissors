struct Field: Equatable, Sendable {
    let scale: Double
    let originX: Double
    let originY: Double
    let ink: Double

    init(arena: Size, diameter: Double, size: Size) {
        let usable = size.width > 0 && size.height > 0 && arena.width > 0 && arena.height > 0
        let fitted = usable
            ? min(
                size.width / (arena.width + diameter),
                size.height / (arena.height + diameter))
            : 0
        scale = fitted
        originX = (size.width - arena.width * fitted) / 2
        originY = (size.height - arena.height * fitted) / 2
        ink = diameter * fitted
    }

    func x(_ position: Double) -> Double { originX + position * scale }
    func y(_ position: Double) -> Double { originY + position * scale }
}
