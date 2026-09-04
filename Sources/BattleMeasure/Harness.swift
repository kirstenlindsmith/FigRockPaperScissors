import BattleFixtures
import Glibc

@_spi(Instrumentation) import BattleEngine

struct Arguments {
    var mode = "battle"
    private var values: [String: String] = [:]

    init(_ raw: [String]) {
        for (i, item) in raw.enumerated() where i > 0 {
            if i == 1 && !item.contains("=") {
                mode = item
                continue
            }
            guard let split = item.firstIndex(of: "=") else { continue }
            values[String(item[item.startIndex..<split])] = String(item[item.index(after: split)...])
        }
    }

    func int(_ key: String, _ fallback: Int) -> Int { values[key].flatMap { Int($0) } ?? fallback }
    func float(_ key: String, _ fallback: Float) -> Float { values[key].flatMap { Float($0) } ?? fallback }
    func text(_ key: String, _ fallback: String) -> String { values[key] ?? fallback }
    func flag(_ key: String, _ fallback: Bool) -> Bool {
        values[key].map { $0 == "1" || $0 == "true" } ?? fallback
    }
    func list(_ key: String) -> [Int] {
        (values[key] ?? "").split(separator: ",").compactMap { Int($0) }
    }
}

func makeSetup(_ arguments: Arguments) -> Setup {
    let n = arguments.int("n", 1500)
    let armies = Armies(rawValue: arguments.text("armies", "even")) ?? .even
    let aspect = arguments.float("aspect", Fixtures.phoneAspect)
    var setup = Fixtures.setup(
        armies, soldiers: n, seed: UInt64(arguments.int("seed", 1)), aspect: aspect
    )
    let counted = arguments.list("counts")
    if counted.count == 3 {
        setup.rock = counted[0]
        setup.paper = counted[1]
        setup.scissors = counted[2]
    }
    return setup
}

func nowNanoseconds() -> Double {
    var stamp = timespec()
    clock_gettime(CLOCK_MONOTONIC, &stamp)
    return Double(stamp.tv_sec) * 1e9 + Double(stamp.tv_nsec)
}

func highWaterKilobytes() -> Int {
    guard let file = fopen("/proc/self/status", "r") else { return 0 }
    defer { fclose(file) }
    var line = [CChar](repeating: 0, count: 256)
    var found = 0
    while fgets(&line, 256, file) != nil {
        let text = String(decoding: line.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        if text.hasPrefix("VmHWM") {
            found = text.split(separator: " ").compactMap { Int($0) }.first ?? 0
        }
    }
    return found
}

func show(_ value: Double, _ places: Int = 3) -> String {
    if value.isNaN { return "nan" }
    if value.isInfinite { return "inf" }
    var scale = 1.0
    for _ in 0..<places { scale *= 10 }
    let negative = value < 0
    let rounded = (abs(value) * scale).rounded()
    if rounded >= Double(Int.max) { return "\(value)" }
    let whole = Int(rounded / scale)
    var fraction = String(Int(rounded) - whole * Int(scale))
    while fraction.count < places { fraction = "0" + fraction }
    return (negative ? "-" : "") + String(whole) + (places > 0 ? "." + fraction : "")
}

func show(_ value: Float, _ places: Int = 3) -> String { show(Double(value), places) }

func quantile(_ sorted: [Double], _ fraction: Double) -> Double {
    guard !sorted.isEmpty else { return 0 }
    return sorted[min(sorted.count - 1, Int(Double(sorted.count) * fraction))]
}

func report(_ head: String, _ parts: [String]) {
    print(head + " " + parts.joined(separator: " "))
}
