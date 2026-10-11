import FitsCullCore
import Foundation
import Testing

@Suite struct MetricsCacheTests {
    static let file = FrameFile(url: URL(fileURLWithPath: "/data/light_001.fits"), size: 51_000_000,
                                modified: Date(timeIntervalSince1970: 1_760_000_000.25))

    @Test func storeAndLookup() throws {
        let cache = MetricsCache(directory: try FITSFixture.tempDirectory())
        let analysis = AnalysisFactory.make(background: 1850, stars: 400, fwhm: 3)
        #expect(cache.lookup(Self.file) == nil)
        cache.store(analysis, for: Self.file)
        #expect(cache.lookup(Self.file) == analysis)
    }

    @Test func modifiedFileMissesCache() throws {
        let cache = MetricsCache(directory: try FITSFixture.tempDirectory())
        cache.store(AnalysisFactory.make(background: 1850, stars: 400, fwhm: 3), for: Self.file)
        let resized = FrameFile(url: Self.file.url, size: Self.file.size + 1, modified: Self.file.modified)
        let touched = FrameFile(url: Self.file.url, size: Self.file.size, modified: Self.file.modified.addingTimeInterval(1))
        #expect(cache.lookup(resized) == nil)
        #expect(cache.lookup(touched) == nil)
    }

    @Test func persistsAcrossInstances() throws {
        let dir = try FITSFixture.tempDirectory()
        let analysis = AnalysisFactory.make(background: 1850, stars: 400, fwhm: 3)
        let first = MetricsCache(directory: dir)
        first.store(analysis, for: Self.file)
        try first.save()
        #expect(MetricsCache(directory: dir).lookup(Self.file) == analysis)
    }

    @Test func nanValuesRoundTrip() throws {
        let dir = try FITSFixture.tempDirectory()
        var analysis = AnalysisFactory.make(background: 1850, stars: 0, fwhm: nil)
        analysis.channels[0].median = .nan
        let first = MetricsCache(directory: dir)
        first.store(analysis, for: Self.file)
        try first.save()
        let loaded = try #require(MetricsCache(directory: dir).lookup(Self.file))
        #expect(loaded.channels[0].median.isNaN)
        #expect(loaded.stars == .none)
    }

    @Test func removeForgetsEntry() throws {
        let cache = MetricsCache(directory: try FITSFixture.tempDirectory())
        cache.store(AnalysisFactory.make(background: 1, stars: 1, fwhm: 1), for: Self.file)
        cache.remove(Self.file.url)
        #expect(cache.lookup(Self.file) == nil)
    }
}
