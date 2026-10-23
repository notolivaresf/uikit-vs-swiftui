/// SplitMix64: tiny, fast, identical on every platform and Swift version (unlike SystemRandomNumberGenerator
/// or Hasher, which are seeded per process).
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    /// True with the given probability (0...1).
    public mutating func chance(_ p: Double) -> Bool {
        Double(next() >> 11) / Double(1 << 53) < p
    }

    public mutating func pick<T>(_ items: [T]) -> T { items[int(0...(items.count - 1))] }
}
