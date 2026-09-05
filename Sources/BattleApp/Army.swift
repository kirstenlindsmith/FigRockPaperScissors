import BattleEngine

public struct Army: Equatable, Sendable {
    public static let range = Double(smallest)...Double(largest)
    static let smallest = 1
    static let largest = 2000
    static let opening = 100

    public internal(set) var typedGlyph: String
    public internal(set) var typedName: String
    public private(set) var soldiers: Int
    let index: Int

    init(index: Int, fields: ArraySlice<String>?) {
        self.index = index
        typedGlyph = ""
        typedName = ""
        soldiers = Army.opening
        guard let fields, fields.count == 3 else { return }
        let parts = Array(fields)
        typedGlyph = parts[0]
        typedName = parts[1]
        if let read = Int(parts[2]) { resize(Double(read)) }
    }

    public var role: String { Words.roles[index] }

    public var glyph: String {
        for cluster in typedGlyph.reversed() where !cluster.isWhitespace {
            return String(cluster)
        }
        return Words.glyphs[index]
    }

    public var name: String {
        typedName.contains { !$0.isWhitespace } ? typedName : role
    }

    public var glyphLabel: String { Words.glyphLabel(role) }
    public var nameLabel: String { Words.nameLabel(role) }
    public var soldiersLabel: String { Words.soldiersLabel(role) }

    var introduction: String { Words.introduction(name, plays: role) }

    var record: [String] { [typedGlyph, typedName, String(soldiers)] }

    mutating func resize(_ value: Double) {
        guard value.isFinite else { return }
        let held = min(max(value, Double(Army.smallest)), Double(Army.largest))
        soldiers = Int(held.rounded())
    }
}

struct Choices {
    static let opening = Choices(record: [])

    private var rock: Army
    private var paper: Army
    private var scissors: Army

    init(record: [String]) {
        let fields: [ArraySlice<String>?] =
            record.count == 9
            ? [record[0..<3], record[3..<6], record[6..<9]]
            : [nil, nil, nil]
        rock = Army(index: 0, fields: fields[0])
        paper = Army(index: 1, fields: fields[1])
        scissors = Army(index: 2, fields: fields[2])
    }

    var all: [Army] { [rock, paper, scissors] }

    mutating func edit(at index: Int, _ change: (inout Army) -> Void) {
        switch index {
        case 0: change(&rock)
        case 1: change(&paper)
        case 2: change(&scissors)
        default: return
        }
    }

    func setup(aspect: Double, seed: UInt64) -> Setup {
        Setup(
            aspect: Float(aspect), seed: seed, rock: rock.soldiers, paper: paper.soldiers,
            scissors: scissors.soldiers)
    }

    var diameter: Double { Double(setup(aspect: 1, seed: 0).soldierDiameter) }
}
