public struct ChannelStats: Sendable, Codable, Equatable {
    public var min: Double
    public var max: Double
    public var mean: Double
    public var median: Double
    public var stdDev: Double
    /// 1,4826 × MAD: stima robusta del rumore.
    public var noise: Double
    /// Frazione (0…1) di pixel ≥ 99,5% del massimo rappresentabile; nil se il livello non è noto.
    public var saturatedFraction: Double?

    public init(min: Double, max: Double, mean: Double, median: Double, stdDev: Double, noise: Double,
                saturatedFraction: Double?) {
        self.min = min
        self.max = max
        self.mean = mean
        self.median = median
        self.stdDev = stdDev
        self.noise = noise
        self.saturatedFraction = saturatedFraction
    }
}

public enum Statistics {
    public static let saturationRatio: Float = 0.995

    public static func channel(_ v: [Float], saturationLevel: Float?) -> ChannelStats {
        guard let range = RobustStats.finiteRange(v) else {
            return ChannelStats(min: .nan, max: .nan, mean: .nan, median: .nan, stdDev: .nan, noise: .nan,
                                saturatedFraction: nil)
        }
        let threshold = saturationLevel.map { $0 * saturationRatio }
        var sum = 0.0, sumSquares = 0.0
        var saturated = 0
        for x in v where x.isFinite {
            let d = Double(x)
            sum += d
            sumSquares += d * d
            if let t = threshold, x >= t { saturated += 1 }
        }
        let n = Double(range.count)
        let mean = sum / n
        let variance = Swift.max(0, sumSquares / n - mean * mean)
        let median = RobustStats.median(v, lo: range.lo, hi: range.hi)
        let mad = RobustStats.mad(v, median: median)
        return ChannelStats(min: Double(range.lo), max: Double(range.hi), mean: mean, median: median,
                            stdDev: variance.squareRoot(), noise: 1.4826 * mad,
                            saturatedFraction: saturationLevel == nil ? nil : Double(saturated) / n)
    }
}
