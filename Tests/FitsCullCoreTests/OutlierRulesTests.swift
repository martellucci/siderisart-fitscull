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

    /// "FWHM alta" solo oltre la mediana di sessione + 25% (scelta dell'utente dopo il confronto con PixInsight).
    @Test func fwhmFlagAbove25Percent() throws {
        let s = try #require(OutlierRules.summary(Self.normal))
        let m = try #require(s.medianFWHM)
        let worse20 = AnalysisFactory.make(background: 1850, stars: 395, fwhm: m * 1.20)
        #expect(!OutlierRules.flags(for: worse20, in: s).contains(.fwhm))
        let worse30 = AnalysisFactory.make(background: 1850, stars: 395, fwhm: m * 1.30)
        #expect(OutlierRules.flags(for: worse30, in: s).contains(.fwhm))
        #expect(AlertSettings.defaults.fwhmExcessPercent == 25)
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
        #expect(AlertSettings.defaults.minBackgroundADU == 3000)
        #expect(AlertSettings.defaults.backgroundExcessPercent == 30)
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
        #expect(AlertSettings.defaults.maxEccentricity == 0.75)
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

    @Test func disabledRulesNeverFlag() throws {
        let s = try #require(OutlierRules.summary(Self.normal + [Self.cloud]))
        var settings = AlertSettings.defaults
        settings.backgroundEnabled = false
        settings.fwhmEnabled = false
        #expect(OutlierRules.flags(for: Self.cloud, in: s, settings: settings) == [.stars])
        settings.starsEnabled = false
        #expect(OutlierRules.flags(for: Self.cloud, in: s, settings: settings).isEmpty)
        let trailed = AnalysisFactory.make(background: 1850, stars: 395, fwhm: 3.1, eccentricity: 0.9)
        settings.eccentricityEnabled = false
        #expect(OutlierRules.flags(for: trailed, in: s, settings: settings).isEmpty)
    }

    @Test func customValuesAreUsed() throws {
        let s = try #require(OutlierRules.summary(Self.normal))  // mediane: fondo ~1855, stelle 395, FWHM 3,1
        var settings = AlertSettings.defaults
        settings.fwhmExcessPercent = 10
        settings.starsMinPercent = 80
        settings.backgroundExcessPercent = 10
        settings.minBackgroundADU = 2000
        settings.maxEccentricity = 0.5
        let frame = AnalysisFactory.make(background: 2100, stars: 300, fwhm: 3.5, eccentricity: 0.6)
        #expect(OutlierRules.flags(for: frame, in: s).isEmpty)
        #expect(OutlierRules.flags(for: frame, in: s, settings: settings) == [.background, .stars, .fwhm, .eccentricity])
    }

    @Test func settingsAreClampedToSensibleRanges() {
        var settings = AlertSettings.defaults
        settings.backgroundExcessPercent = -5
        settings.minBackgroundADU = 100_000
        settings.starsMinPercent = 150
        settings.fwhmExcessPercent = 900
        settings.maxEccentricity = 1.5
        let c = settings.clamped()
        #expect(c.backgroundExcessPercent == 0)
        #expect(c.minBackgroundADU == 65535)
        #expect(c.starsMinPercent == 100)
        #expect(c.fwhmExcessPercent == 500)
        #expect(c.maxEccentricity == 1)
        #expect(AlertSettings.defaults.clamped() == .defaults)
    }

    @Test func settingsRoundTripThroughJSON() throws {
        var settings = AlertSettings.defaults
        settings.starsEnabled = false
        settings.fwhmExcessPercent = 40
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(AlertSettings.self, from: data) == settings)
    }

    @Test func settingsPersistInUserDefaults() throws {
        let suite = "FitsCullTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(AlertSettings.load(from: defaults) == .defaults)
        var settings = AlertSettings.defaults
        settings.eccentricityEnabled = false
        settings.maxEccentricity = 0.6
        settings.save(to: defaults)
        #expect(AlertSettings.load(from: defaults) == settings)
        defaults.set(Data("garbage".utf8), forKey: AlertSettings.defaultsKey)
        #expect(AlertSettings.load(from: defaults) == .defaults)
        var wild = AlertSettings.defaults
        wild.starsMinPercent = 400
        wild.save(to: defaults)
        #expect(AlertSettings.load(from: defaults).starsMinPercent == 100)
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
