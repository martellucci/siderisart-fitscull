import FitsCullCore
import Foundation

enum AnalysisFactory {
    /// Analisi sintetica: FWHM in pixel, scala 1,88″/px.
    static func make(background: Double, stars: Int, fwhm: Double?, eccentricity: Double? = 0.3) -> FrameAnalysis {
        let channel = ChannelStats(min: 0, max: 65535, mean: background, median: background, stdDev: 10, noise: 10,
                                   saturatedFraction: 0)
        let metrics = StarMetrics(count: stars, hfr: fwhm.map { $0 / 2 }, fwhm: fwhm,
                                  fwhmArcsec: fwhm.map { $0 * 1.88 }, eccentricity: stars > 0 ? eccentricity : nil)
        return FrameAnalysis(meta: FrameMeta(header: FITSHeader(cards: [], byteLength: 0)), channels: [channel], stars: metrics)
    }
}
