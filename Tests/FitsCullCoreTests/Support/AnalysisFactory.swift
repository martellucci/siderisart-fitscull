import FitsCullCore
import Foundation

enum AnalysisFactory {
    /// Analisi sintetica: FWHM in pixel, scala 1,88″/px.
    /// `stars: nil` = file di calibrazione (metriche stellari non applicabili).
    static func make(background: Double, stars: Int?, fwhm: Double?, eccentricity: Double? = 0.3,
                     filter: String? = nil, scale: Bool = true) -> FrameAnalysis {
        let channel = ChannelStats(min: 0, max: 65535, mean: background, median: background, stdDev: 10, noise: 10,
                                   saturatedFraction: 0)
        let metrics = stars.map { count in
            StarMetrics(count: count, hfr: fwhm.map { $0 / 2 }, fwhm: fwhm,
                        fwhmArcsec: scale ? fwhm.map { $0 * 1.88 } : nil, eccentricity: count > 0 ? eccentricity : nil)
        }
        var meta = FrameMeta(header: FITSHeader(cards: [], byteLength: 0))
        meta.filter = filter
        return FrameAnalysis(meta: meta, channels: [channel], stars: metrics)
    }
}
