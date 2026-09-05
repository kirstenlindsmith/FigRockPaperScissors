import BattleEngine

public final class Director {
    static let slice = 0.05
    static let diameter = Choices.opening.diameter

    var battle: Battle?
    private var running = false
    private var speed: Speed = .normal
    private var celebration: Duration = .zero
    private var seed: UInt64
    private var choices: Choices
    private var configuring = false

    public init(seed: UInt64 = .random(in: UInt64.min...UInt64.max), record: [String]) {
        self.seed = seed
        choices = Choices(record: record)
    }

    public func handle(_ intent: Intent, surface: Surface) -> Frame {
        let layout = Layout(surface, diameter: Director.diameter)
        switch intent {
        case .newBattle:
            configuring = false
            stage(layout)
        case .go: running = true
        case .pause: running = false
        case .home:
            configuring = false
            battle = nil
        case .speed(let chosen): speed = chosen
        case .config:
            configuring = true
            battle = nil
        case .glyph(let index, let typed): choices.edit(at: index) { $0.typedGlyph = typed }
        case .name(let index, let typed): choices.edit(at: index) { $0.typedName = typed }
        case .soldiers(let index, let value): choices.edit(at: index) { $0.resize(value) }
        }
        return assemble(layout, reduceMotion: surface.reduceMotion)
    }

    public func frame(surface: Surface, seconds: Double) -> Frame {
        let layout = Layout(surface, diameter: Director.diameter)
        deliver(seconds)
        return assemble(layout, reduceMotion: surface.reduceMotion)
    }

    private func stage(_ layout: Layout) {
        guard layout.field.width > 0, layout.field.height > 0 else { return }
        let made = choices.setup(aspect: layout.field.width / layout.field.height, seed: seed)
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
        let armies = choices.all
        guard let battle else {
            let phase: Phase = configuring ? .config : .landing
            return Frame(
                phase: phase, layout: layout, armies: armies, soldiers: [], soldierPoints: 0,
                confetti: [], confettiPoints: 0, counts: [], clock: "", banner: nil,
                summary: "", config: nil,
                primary: Words.primary(phase: phase, started: false),
                secondary: Words.secondary(phase: phase, speed: speed),
                wantsFrames: false)
        }
        let census = battle.census
        let phase: Phase = census.isOver ? .finished : (running ? .watching : .held)
        let arena = battle.setup.arena
        let field = Field(
            arena: Size(width: Double(arena.x), height: Double(arena.y)),
            diameter: Double(battle.setup.soldierDiameter),
            size: layout.field)
        var soldiers: [Dot] = []
        soldiers.reserveCapacity(battle.setup.count)
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
        let reading = Clock.tenths(battle.elapsed)
        let seconds = "\(reading) seconds"
        let confettiPoints = layout.field.width / 12
        let winner = census.victor.map { Int($0.rawValue) }
        let confetti = winner.map {
            Confetti.dots(
                glyph: $0, seconds: Clock.seconds(celebration), field: layout.field,
                points: confettiPoints, reduceMotion: reduceMotion)
        } ?? []
        var summary = ""
        for index in counts.indices { summary += "\(armies[index].name) \(counts[index]), " }
        summary += seconds
        return Frame(
            phase: phase, layout: layout, armies: armies, soldiers: soldiers,
            soldierPoints: field.ink,
            confetti: confetti, confettiPoints: confettiPoints, counts: counts,
            clock: "\(reading) sec",
            banner: winner.map {
                Banner(
                    winner: "\(armies[$0].glyph) wins!", duration: seconds,
                    spoken: "\(armies[$0].name) wins after \(seconds)")
            },
            summary: summary,
            config: phase == .held ? Words.config : nil,
            primary: Words.primary(phase: phase, started: battle.elapsed > .zero),
            secondary: Words.secondary(phase: phase, speed: speed),
            wantsFrames: phase == .watching || !confetti.isEmpty)
    }
}
