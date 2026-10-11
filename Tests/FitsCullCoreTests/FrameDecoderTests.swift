import FitsCullCore
import Foundation
import Testing

@Suite struct FrameDecoderTests {
    static func image(_ pixels: [Float], width: Int, height: Int) -> FITSImage {
        FITSImage(header: FITSHeader(cards: [], byteLength: 0), width: width, height: height, bitpix: 16,
                  pixels: pixels, maxRepresentable: 65535)
    }

    @Test func superpixelRGGB() {
        // riga 0: R1 G2 R3 G4 / riga 1: G5 B6 G7 B8
        let planar = FrameDecoder.decode(Self.image([1, 2, 3, 4, 5, 6, 7, 8], width: 4, height: 2), pattern: .rggb)
        #expect(planar.width == 2 && planar.height == 1)
        #expect(planar.binFactor == 2)
        #expect(planar.planes[0] == [1, 3])
        #expect(planar.planes[1] == [3.5, 5.5])
        #expect(planar.planes[2] == [6, 8])
    }

    /// Celle 2×2 nell'ordine (0,0), (1,0), (0,1), (1,1) con R = 1, G = 11, B = 21.
    @Test(arguments: [
        (BayerPattern.rggb, [Float(1), 11, 11, 21]),
        (BayerPattern.bggr, [Float(21), 11, 11, 1]),
        (BayerPattern.grbg, [Float(11), 1, 21, 11]),
        (BayerPattern.gbrg, [Float(11), 21, 1, 11]),
    ])
    func everyPatternDecodes(pattern: BayerPattern, cell: [Float]) {
        let planar = FrameDecoder.decode(Self.image(cell, width: 2, height: 2), pattern: pattern)
        #expect(planar.planes.map { $0[0] } == [1, 11, 21])
    }

    @Test func oddDimensionsAreTruncated() {
        let planar = FrameDecoder.decode(Self.image([Float](repeating: 1, count: 15), width: 5, height: 3), pattern: .rggb)
        #expect(planar.width == 2 && planar.height == 1)
    }

    @Test func monoIsPassedThrough() {
        let planar = FrameDecoder.decode(Self.image([1, 2, 3, 4], width: 2, height: 2), pattern: nil)
        #expect(planar.binFactor == 1)
        #expect(!planar.isColor)
        #expect(planar.planes == [[1, 2, 3, 4]])
        #expect(planar.luminance() == [1, 2, 3, 4])
    }

    @Test func cfaChannelsSplitColours() {
        let channels = FrameDecoder.cfaChannels(Self.image([1, 2, 3, 4, 5, 6, 7, 8], width: 4, height: 2), pattern: .rggb)
        #expect(channels.count == 3)
        #expect(channels[0] == [1, 3])
        #expect(channels[1].sorted() == [2, 4, 5, 7])
        #expect(channels[2] == [6, 8])
        #expect(FrameDecoder.cfaChannels(Self.image([1, 2], width: 2, height: 1), pattern: nil) == [[1, 2]])
    }

    @Test func luminanceAveragesChannels() {
        let planar = PlanarImage(width: 1, height: 1, binFactor: 2, planes: [[3], [6], [9]])
        #expect(planar.luminance() == [6])
    }
}
