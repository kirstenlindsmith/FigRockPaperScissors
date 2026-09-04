enum Clock {
    static func tenths(_ elapsed: Duration) -> String {
        let parts = elapsed.components
        let whole = max(parts.seconds, 0)
        let tenths = whole * 10 + max(parts.attoseconds, 0) / 100_000_000_000_000_000
        return "\(tenths / 10).\(tenths % 10)"
    }

    static func seconds(_ elapsed: Duration) -> Double {
        let parts = elapsed.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
