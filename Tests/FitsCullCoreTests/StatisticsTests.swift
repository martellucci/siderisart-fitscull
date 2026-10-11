import FitsCullCore
import Foundation
import Testing

@Suite struct StatisticsTests {
    @Test func medianAndMADWithOutlier() {
        let r = RobustStats.medianAndMAD([1, 2, 3, 4, 5, 6, 7, 8, 100])
        #expect(abs(r.median - 5) < 0.01)
        #expect(abs(r.mad - 2) < 0.01)
    }

    @Test func evenCountUsesLowerMedian() {
        #expect(abs(RobustStats.medianAndMAD([1, 2, 3, 4]).median - 2) < 0.001)
    }

    @Test func constantData() {
        let r = RobustStats.medianAndMAD([7, 7, 7])
        #expect(r.median == 7)
        #expect(r.mad == 0)
    }

    @Test func nonFiniteValuesAreIgnored() {
        #expect(abs(RobustStats.medianAndMAD([1, .nan, 3, 2, .infinity]).median - 2) < 0.001)
        #expect(RobustStats.medianAndMAD([.nan]).median.isNaN)
    }

    @Test func largeIntegerData() {
        let values = (0..<99_999).map { Float($0 % 1000) }
        #expect(abs(RobustStats.medianAndMAD(values).median - 499) < 0.05)
    }

    @Test func exactMedian() {
        #expect(RobustStats.exactMedian([3, 1, 2]) == 2)
        #expect(RobustStats.exactMedian([4, 1, 2, 3]) == 2.5)
        #expect(RobustStats.exactMedian([]).isNaN)
    }

    @Test func channelStatistics() {
        let s = Statistics.channel([2, 4, 4, 4, 5, 5, 7, 9], saturationLevel: nil)
        #expect(s.min == 2 && s.max == 9)
        #expect(abs(s.mean - 5) < 1e-9)
        #expect(abs(s.stdDev - 2) < 1e-9)
        #expect(abs(s.median - 4) < 0.001)
        #expect(s.saturatedFraction == nil)
    }

    @Test func saturationFraction() {
        let values: [Float] = [65535, 65535] + [Float](repeating: 100, count: 8)
        let s = Statistics.channel(values, saturationLevel: 65535)
        #expect(s.saturatedFraction == 0.2)
    }

    @Test func noiseIsScaledMAD() {
        let s = Statistics.channel([1, 2, 3, 4, 5, 6, 7, 8, 100], saturationLevel: nil)
        #expect(abs(s.noise - 1.4826 * 2) < 0.02)
    }
}
