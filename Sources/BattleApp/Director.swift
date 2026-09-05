import BattleEngine

public final class Director {
    static let slice = 0.05
    static let armySize = 100
    static let diameter = Double(Director.setup(aspect: 1).soldierDiameter)

    var battle: Battle?
    private var running = false
    private var speed: Speed = .normal
    private var celebration: Duration = .zero
    private var seed: UInt64

    public init(seed: UInt64 = .random(in: UInt64.min...UInt64.max)) {
        self.seed = seed
    }

    public func handle(_ intent: Intent, surface: Surface) -> Frame {
        let layout = Layout(surface, diameter: Director.diameter)
        switch intent {
        case .newBattle: stage(layout)
        case .go: running = true
        case .pause: running = false
        case .home: battle = nil
        case .speed(let chosen): speed = chosen
        }
        return assemble(layout, reduceMotion: surface.reduceMotion)
    }

    public func frame(surface: Surface, seconds: Double) -> Frame {
        let layout = Layout(surface, diameter: Director.diameter)
        deliver(seconds)
        return assemble(layout, reduceMotion: surface.reduceMotion)
    }

    static func setup(aspect: Double) -> Setup {
        Setup(
            aspect: Float(aspect),
            seed: 0,
            rock: Director.armySize,
            paper: Director.armySize,
            scissors: Director.armySize
        )
    }

    private func stage(_ layout: Layout) {
        guard layout.field.width > 0, layout.field.height > 0 else { return }
        var made = Director.setup(aspect: layout.field.width / layout.field.height)
        made.seed = seed
        seed &+= 1
        battle = Battle(made)
        running = false
        celebration = .zero
    }

    private func deliver(_ seconds: Double) {
        guard let battle else { return }
        let delivered = seconds.isFinite ? min(max(seconds, 0), Director.slice) : 0
        if battle.census.isOver {
            celebration += .seconds(delivered)
        } else if running {
            battle.advance(by: .seconds(delivered) * speed.rawValue)
        }
    }

    private func assemble(_ layout: Layout, reduceMotion: Bool) -> Frame {
        guard let battle else {
            return Frame(
                phase: .landing, layout: layout, soldiers: [], soldierPoints: 0,
                confetti: [], confettiPoints: 0, counts: [], clock: "", banner: nil,
                summary: "",
                primary: Words.primary(phase: .landing, started: false),
                secondary: Words.secondary(phase: .landing, speed: speed),
                wantsFrames: false)
        }
        let census = battle.census
        let phase: Phase = census.isOver ? .finished : (running ? .watching : .held)
        let arena = battle.arena
        let field = Field(
            arena: Size(width: Double(arena.x), height: Double(arena.y)),
            diameter: Double(battle.soldierDiameter),
            size: layout.field)
        var soldiers: [Dot] = []
        soldiers.reserveCapacity(census.total)
        battle.withSoldiers { positions, kinds in
            for index in positions.indices {
                soldiers.append(
                    Dot(
                        glyph: Int(kinds[index].rawValue),
                        x: field.x(Double(positions[index].x)),
                        y: field.y(Double(positions[index].y))))
            }
        }
        let counts = Kind.allCases.map { census[$0] }
        let clock = Clock.tenths(battle.elapsed)
        let confettiPoints = layout.field.width / 12
        let winner = census.victor.map { Int($0.rawValue) }
        let confetti = winner.map {
            Confetti.dots(
                glyph: $0, seconds: Clock.seconds(celebration), field: layout.field,
                points: confettiPoints, reduceMotion: reduceMotion)
        } ?? []
        var summary = ""
        for index in counts.indices { summary += "\(Words.names[index]) \(counts[index]), " }
        summary += "\(clock) seconds"
        return Frame(
            phase: phase, layout: layout, soldiers: soldiers, soldierPoints: field.ink,
            confetti: confetti, confettiPoints: confettiPoints, counts: counts, clock: clock,
            banner: winner.map {
                Banner(
                    winner: "\(Words.glyphs[$0]) wins!", duration: "\(clock) seconds",
                    spoken: "\(Words.names[$0]) wins after \(clock) seconds")
            },
            summary: summary,
            primary: Words.primary(phase: phase, started: battle.elapsed > .zero),
            secondary: Words.secondary(phase: phase, speed: speed),
            wantsFrames: phase == .watching || !confetti.isEmpty)
    }
}
