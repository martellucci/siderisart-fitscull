import Foundation

/// Generatore deterministico SplitMix64 con gaussiane Box-Muller.
struct TestRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func uniform() -> Double { Double(next() >> 11) / Double(1 << 53) }

    mutating func gaussian(mean: Double = 0, sigma: Double = 1) -> Double {
        let u1 = max(uniform(), 1e-12), u2 = uniform()
        return mean + sigma * (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}
