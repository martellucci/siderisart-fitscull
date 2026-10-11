/// Mediana e MAD in O(n) con istogramma a 65536 classi: esatte per dati interi a 16 bit,
/// risoluzione (max − min) / 65535 negli altri casi. I valori non finiti sono ignorati.
public enum RobustStats {
    public static let histogramBins = 65536

    public static func finiteRange(_ v: [Float]) -> (lo: Float, hi: Float, count: Int)? {
        var lo = Float.infinity, hi = -Float.infinity, n = 0
        for x in v where x.isFinite {
            lo = min(lo, x)
            hi = max(hi, x)
            n += 1
        }
        return n == 0 ? nil : (lo, hi, n)
    }

    public static func median(_ v: [Float], lo: Float, hi: Float) -> Double {
        guard hi > lo else { return Double(lo) }
        let width = (hi - lo) / Float(histogramBins - 1)
        var hist = [Int](repeating: 0, count: histogramBins)
        var n = 0
        for x in v where x.isFinite {
            let i = Int(((x - lo) / width).rounded())
            hist[min(max(i, 0), histogramBins - 1)] += 1
            n += 1
        }
        return Double(lo) + Double(lowerMedianBin(hist, count: n)) * Double(width)
    }

    public static func mad(_ v: [Float], median: Double) -> Double {
        let m = Float(median)
        var maxDev: Float = 0
        var n = 0
        for x in v where x.isFinite {
            maxDev = max(maxDev, abs(x - m))
            n += 1
        }
        guard maxDev > 0, n > 0 else { return 0 }
        let width = maxDev / Float(histogramBins - 1)
        var hist = [Int](repeating: 0, count: histogramBins)
        for x in v where x.isFinite {
            hist[min(Int((abs(x - m) / width).rounded()), histogramBins - 1)] += 1
        }
        return Double(lowerMedianBin(hist, count: n)) * Double(width)
    }

    public static func medianAndMAD(_ v: [Float]) -> (median: Double, mad: Double) {
        guard let range = finiteRange(v) else { return (.nan, .nan) }
        let m = median(v, lo: range.lo, hi: range.hi)
        return (m, mad(v, median: m))
    }

    /// Mediana esatta (media dei due centrali per n pari), per vettori piccoli.
    public static func exactMedian(_ v: [Double]) -> Double {
        let s = v.filter(\.isFinite).sorted()
        guard !s.isEmpty else { return .nan }
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    static func lowerMedianBin(_ hist: [Int], count: Int) -> Int {
        let target = (count + 1) / 2
        var accumulated = 0
        for i in hist.indices {
            accumulated += hist[i]
            if accumulated >= target { return i }
        }
        return hist.count - 1
    }
}
