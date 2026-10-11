import FitsCullCore
import Foundation
import Testing

@Suite struct FrameAnalyzerTests {
    /// Stelle "grigie" su tutti i pixel CFA, in coordinate a piena risoluzione.
    static let stars: [SyntheticStar] = [40.0, 98, 156, 214].flatMap { y in
        [40.0, 98, 156, 214].map { x in SyntheticStar(x: x, y: y, amplitude: 3000, sigmaX: 3, sigmaY: 3) }
    }

    static func file(bayer: Bool) -> Data {
        let field = SyntheticField.make(width: 256, height: 256, background: { _, _ in 1500 }, noise: 8, stars: stars)
        var extra = [FITSFixture.kv("IMAGETYP", "'Light'"), FITSFixture.kv("XPIXSZ", "3.76"),
                     FITSFixture.kv("FOCALLEN", "412"), FITSFixture.kv("EXPTIME", "120.")]
        if bayer { extra.append(FITSFixture.kv("BAYERPAT", "'RGGB'")) }
        return FITSFixture.image(bitpix: 16, width: 256, height: 256, pixels: field.map(Double.init),
                                 bzero: 32768, extra: extra)
    }

    @Test func analyzesColourFile() throws {
        let url = try FITSFixture.write(Self.file(bayer: true))
        let (analysis, preview) = try FrameAnalyzer.analyze(url: url, includePreview: true)
        #expect(analysis.channels.count == 3)
        #expect(analysis.channelNames == ["R", "G", "B"])
        #expect(analysis.meta.imageType == .light)
        #expect(abs(analysis.background - 1500) < 5)
        #expect(analysis.stars.count == 16)
        let scale = try #require(analysis.meta.pixelScale)
        #expect(abs((analysis.stars.fwhmArcsec ?? 0) - (analysis.stars.fwhm ?? 0) * scale * 2) < 1e-9)
        let p = try #require(preview)
        #expect(p.image.width == 128 && p.image.height == 128 && p.image.isColor)
        #expect(p.normalization == 65535)
    }

    @Test func analyzesMonoFile() throws {
        let url = try FITSFixture.write(Self.file(bayer: false))
        let (analysis, preview) = try FrameAnalyzer.analyze(url: url, includePreview: true)
        #expect(analysis.channels.count == 1)
        #expect(analysis.channelNames == ["L"])
        #expect(analysis.stars.count == 16)
        #expect(preview?.image.binFactor == 1)
        #expect(preview?.image.isColor == false)
    }

    @Test func previewWithoutAnalysis() throws {
        let url = try FITSFixture.write(Self.file(bayer: true))
        let source = try FrameAnalyzer.preview(url: url)
        #expect(source.image.width == 128)
    }

    @Test func skipsPreviewWhenNotRequested() throws {
        let url = try FITSFixture.write(Self.file(bayer: true))
        #expect(try FrameAnalyzer.analyze(url: url, includePreview: false).preview == nil)
    }

    @Test func unsupportedFileThrows() throws {
        let url = try FITSFixture.write(FITSFixture.image(bitpix: -64, width: 2, height: 2, pixels: [1, 2, 3, 4]))
        #expect(throws: FITSError.self) { try FrameAnalyzer.analyze(url: url, includePreview: false) }
    }
}
