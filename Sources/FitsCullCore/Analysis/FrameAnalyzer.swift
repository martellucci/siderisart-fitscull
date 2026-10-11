import Foundation

public struct FrameAnalysis: Sendable, Codable, Equatable {
    public var meta: FrameMeta
    /// [R, G, B] per immagini Bayer, [L] per mono.
    public var channels: [ChannelStats]
    public var stars: StarMetrics

    public init(meta: FrameMeta, channels: [ChannelStats], stars: StarMetrics) {
        self.meta = meta
        self.channels = channels
        self.stars = stars
    }

    /// Fondo cielo: media delle mediane dei canali.
    public var background: Double {
        channels.map(\.median).reduce(0, +) / Double(max(channels.count, 1))
    }

    public var noise: Double {
        channels.map(\.noise).reduce(0, +) / Double(max(channels.count, 1))
    }

    public var saturatedFraction: Double? { channels.compactMap(\.saturatedFraction).max() }

    public var channelNames: [String] { channels.count == 3 ? ["R", "G", "B"] : ["L"] }
}

public struct PreviewSource: Sendable {
    public let image: PlanarImage
    /// Valore che corrisponde al bianco (massimo rappresentabile o massimo dei dati).
    public let normalization: Float
}

public enum FrameAnalyzer {
    public static func analyze(url: URL, includePreview: Bool) throws -> (analysis: FrameAnalysis, preview: PreviewSource?) {
        analyze(try FITSReader.read(url: url), includePreview: includePreview)
    }

    public static func analyze(_ fits: FITSImage, includePreview: Bool) -> (analysis: FrameAnalysis, preview: PreviewSource?) {
        let meta = FrameMeta(header: fits.header)
        let pattern = meta.bayerPattern.flatMap(BayerPattern.init(rawValue:))
        let channels = FrameDecoder.cfaChannels(fits, pattern: pattern)
            .map { Statistics.channel($0, saturationLevel: fits.maxRepresentable) }
        let planar = FrameDecoder.decode(fits, pattern: pattern)
        let stars = StarDetector.detect(planar.luminance(), width: planar.width, height: planar.height,
                                        saturationLevel: fits.maxRepresentable,
                                        arcsecPerPixel: meta.pixelScale.map { $0 * Double(planar.binFactor) })
        let analysis = FrameAnalysis(meta: meta, channels: channels, stars: stars)
        return (analysis, includePreview ? PreviewSource(image: planar, normalization: normalization(fits)) : nil)
    }

    /// Solo decodifica, per file già analizzati (metriche in cache).
    public static func preview(url: URL) throws -> PreviewSource {
        let fits = try FITSReader.read(url: url)
        let pattern = FrameMeta(header: fits.header).bayerPattern.flatMap(BayerPattern.init(rawValue:))
        return PreviewSource(image: FrameDecoder.decode(fits, pattern: pattern), normalization: normalization(fits))
    }

    static func normalization(_ fits: FITSImage) -> Float {
        if let m = fits.maxRepresentable, m > 0 { return m }
        return RobustStats.finiteRange(fits.pixels)?.hi ?? 1
    }
}
