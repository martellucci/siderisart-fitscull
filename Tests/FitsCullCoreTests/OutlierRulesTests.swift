import FitsCullCore
import Foundation
import Testing

@Suite struct OutlierRulesTests {
    static var normal: [FrameAnalysis] {
        (0..<10).map { AnalysisFactory.make(background: 1850 + Double($0), stars: 400 - $0, fwhm: 3.0 + 0.02 * Double($0)) }
    }
    static let cloud = AnalysisFactory.make(background: 3200, stars: 120, fwhm: 6.0)

    @Test func summaryUsesMedians() throws {
        let s = try #require(OutlierRules.summary(Self.normal + [Self.cloud]))
        #expect(abs(s.medianBackground - 1855) < 0.001)
        #expect(s.medianStars == 395)
        #expect(abs((s.medianFWHM ?? 0) - 3.1) < 0.001)
    }

    @Test func cloudyFrameIsFlagged() throws {
        let s = try #require(OutlierRules.summary(Self.normal + [Self.cloud]))
        #expect(OutlierRules.flags(for: Self.cloud, in: s) == [.background, .stars, .fwhm])
        #expect(OutlierRules.flags(for: Self.normal[3], in: s).isEmpty)
    }

    /// "Fondo alto" solo se oltre 3000 ADU **e** oltre +30% della mediana di sessione.
    @Test func backgroundNeedsBothAbsoluteAndRelativeExcess() throws {
        let s = try #require(OutlierRules.summary(Self.normal))  // mediana fondo ~1855
        let relativeOnly = AnalysisFactory.make(background: 2600, stars: 395, fwhm: 3.1)
        #expect(!OutlierRules.flags(for: relativeOnly, in: s).contains(.background))
        let both = AnalysisFactory.make(background: 3200, stars: 395, fwhm: 3.1)
        #expect(OutlierRules.flags(for: both, in: s).contains(.background))
        let brightSession = (0..<10).map { AnalysisFactory.make(background: 2900 + Double($0), stars: 400, fwhm: 3) }
        let sb = try #require(OutlierRules.summary(brightSession))
        let absoluteOnly = AnalysisFactory.make(background: 3100, stars: 400, fwhm: 3)
        #expect(!OutlierRules.flags(for: absoluteOnly, in: sb).contains(.background))
        #expect(OutlierRules.minBackgroundAlert == 3000)
    }

    @Test func zeroStarFrameIsFlaggedNotCrashing() throws {
        let empty = AnalysisFactory.make(background: 1860, stars: 0, fwhm: nil)
        let s = try #require(OutlierRules.summary(Self.normal + [empty]))
        #expect(OutlierRules.flags(for: empty, in: s) == [.stars])
    }

    /// Soglia fissa 0,75 (FitsCull legge l'eccentricità ~6–12% più alta di PixInsight).
    @Test func eccentricityFlag() throws {
        let s = try #require(OutlierRules.summary(Self.normal))
        let trailed = AnalysisFactory.make(background: 1850, stars: 395, fwhm: 3.1, eccentricity: 0.8)
        #expect(OutlierRules.flags(for: trailed, in: s) == [.eccentricity])
        let slightlyElongated = AnalysisFactory.make(background: 1850, stars: 395, fwhm: 3.1, eccentricity: 0.7)
        #expect(OutlierRules.flags(for: slightlyElongated, in: s).isEmpty)
        #expect(OutlierRules.maxEccentricity == 0.75)
    }

    @Test func calibrationFramesAreNeverFlaggedForStars() throws {
        let darks = (0..<5).map { AnalysisFactory.make(background: 500 + Double($0), stars: nil, fwhm: nil) }
        let s = try #require(OutlierRules.summary(darks))
        #expect(s.medianFWHM == nil)
        #expect(OutlierRules.flags(for: darks[0], in: s).isEmpty)
        #expect(!Thresholds(maxFWHM: 1, minStars: 10, maxEccentricity: 0.1).violates(darks[0]))
        #expect(Thresholds(maxBackground: 400).violates(darks[0]))
    }

    @Test func emptySessionHasNoSummary() {
        #expect(OutlierRules.summary([]) == nil)
    }

    @Test func thresholds() {
        let normal = Self.normal[0]  // FWHM 3 px = 5,64″
        #expect(!Thresholds().violates(Self.cloud))
        #expect(Thresholds(maxFWHM: 8).violates(Self.cloud))
        #expect(!Thresholds(maxFWHM: 8).violates(normal))
        #expect(Thresholds(minStars: 200).violates(Self.cloud))
        #expect(Thresholds(maxBackground: 2000).violates(Self.cloud))
        #expect(Thresholds(maxEccentricity: 0.2).violates(normal))
        let empty = AnalysisFactory.make(background: 1850, stars: 0, fwhm: nil)
        #expect(!Thresholds(maxFWHM: 8).violates(empty))
        #expect(Thresholds(minStars: 10).violates(empty))
    }
}
