import FitsCullCore
import Foundation
import Testing

@Suite struct MetricSeriesTests {
    static func url(_ n: Int) -> URL { URL(fileURLWithPath: "/tmp/f\(n).fits") }

    /// Una colonna per frame nell'ordine dato; i frame non ancora analizzati restano vuoti
    /// così i quattro grafici restano allineati.
    @Test func barsFollowInputOrderWithGaps() {
        let s = MetricSeries(.stars, frames: [
            (Self.url(1), AnalysisFactory.make(background: 1800, stars: 400, fwhm: 3), false),
            (Self.url(2), nil, false),
            (Self.url(3), AnalysisFactory.make(background: 1900, stars: 300, fwhm: 3), true),
        ])
        #expect(s.bars.map(\.id) == [Self.url(1), Self.url(2), Self.url(3)])
        #expect(s.bars.map(\.value) == [400, nil, 300])
        #expect(s.bars.map(\.rejected) == [false, false, true])
        #expect(s.value(for: Self.url(3)) == 300)
        #expect(s.value(for: Self.url(2)) == nil)
    }

    @Test func medianIgnoresGaps() {
        let s = MetricSeries(.background, frames: [
            (Self.url(1), AnalysisFactory.make(background: 1000, stars: 1, fwhm: 3), false),
            (Self.url(2), nil, false),
            (Self.url(3), AnalysisFactory.make(background: 3000, stars: 1, fwhm: 3), false),
            (Self.url(4), AnalysisFactory.make(background: 1200, stars: 1, fwhm: 3), false),
        ])
        #expect(s.median == 1200)
    }

    /// FWHM in ″ solo se tutti i frame misurati hanno la scala; altrimenti tutti in pixel (mai unità miste).
    @Test func fwhmInArcsecOnlyWhenEveryFrameHasScale() {
        let a = AnalysisFactory.make(background: 1, stars: 10, fwhm: 2)
        let b = AnalysisFactory.make(background: 1, stars: 10, fwhm: 3)
        let noScale = AnalysisFactory.make(background: 1, stars: 10, fwhm: 4, scale: false)
        let withScale = MetricSeries(.fwhm, frames: [(Self.url(1), a, false), (Self.url(2), b, false)])
        #expect(withScale.inArcsec)
        let arcsec: [Double?] = [2 * 1.88, 3 * 1.88]
        #expect(withScale.bars.map(\.value) == arcsec)
        let mixed = MetricSeries(.fwhm, frames: [(Self.url(1), a, false), (Self.url(2), noScale, false)])
        #expect(!mixed.inArcsec)
        #expect(mixed.bars.map(\.value) == [2, 4])
    }

    @Test func eccentricityAndMissingStarMetrics() {
        let calibration = AnalysisFactory.make(background: 500, stars: nil, fwhm: nil)
        let light = AnalysisFactory.make(background: 1800, stars: 50, fwhm: 3, eccentricity: 0.42)
        let frames = [(Self.url(1), Optional(calibration), false), (Self.url(2), Optional(light), false)]
        #expect(MetricSeries(.eccentricity, frames: frames).bars.map(\.value) == [nil, 0.42])
        #expect(MetricSeries(.stars, frames: frames).bars.map(\.value) == [nil, 50])
        #expect(MetricSeries(.background, frames: frames).bars.map(\.value) == [500, 1800])
    }

    /// Asse verticale dal minimo al massimo con un 5% di margine, come in PixInsight;
    /// una serie piatta ha comunque un intervallo non nullo.
    @Test func axisDomain() throws {
        let frames = [2.0, 4.0, 3.0].enumerated().map { i, v in
            (Self.url(i), Optional(AnalysisFactory.make(background: v, stars: 1, fwhm: 3)), false)
        }
        let domain = try #require(MetricSeries(.background, frames: frames).axisDomain)
        #expect(abs(domain.lowerBound - 1.9) < 1e-9 && abs(domain.upperBound - 4.1) < 1e-9)
        let flat = MetricSeries(.background, frames: [(Self.url(1), AnalysisFactory.make(background: 3, stars: 1, fwhm: 3), false)])
        let flatDomain = try #require(flat.axisDomain)
        #expect(flatDomain.contains(3) && flatDomain.lowerBound < flatDomain.upperBound)
        #expect(MetricSeries(.stars, frames: [(Self.url(1), nil, false)]).axisDomain == nil)
    }

    /// Icona sul grafico: ordine di ripresa → crescente → decrescente → di nuovo ripresa.
    /// A parità di valore resta l'ordine di ripresa; i frame senza valore vanno sempre in fondo.
    @Test func sortedBars() {
        let values: [Double?] = [3, nil, 1, 2, 1]
        let frames = values.enumerated().map { i, v in
            (Self.url(i), v.map { AnalysisFactory.make(background: $0, stars: 1, fwhm: 3) }, false)
        }
        let s = MetricSeries(.background, frames: frames)
        #expect(s.sorted(.capture) == s)
        #expect(s.sorted(.ascending).bars.map(\.id) == [Self.url(2), Self.url(4), Self.url(3), Self.url(0), Self.url(1)])
        #expect(s.sorted(.descending).bars.map(\.id) == [Self.url(0), Self.url(3), Self.url(2), Self.url(4), Self.url(1)])
        #expect(s.sorted(.ascending).median == s.median)
        #expect(BarOrder.capture.next == .ascending)
        #expect(BarOrder.ascending.next == .descending)
        #expect(BarOrder.descending.next == .capture)
    }
}
