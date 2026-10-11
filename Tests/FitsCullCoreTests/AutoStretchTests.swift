import FitsCullCore
import Foundation
import Testing

@Suite struct AutoStretchTests {
    static func noisyPlane(count: Int, mean: Double, sigma: Double, seed: UInt64) -> [Float] {
        var rng = TestRandom(seed: seed)
        return (0..<count).map { _ in Float(rng.gaussian(mean: mean, sigma: sigma)) }
    }

    static func byteMedian(_ s: StretchedImage, channel: Int) -> Int {
        let values = stride(from: channel, to: s.rgba.count, by: 4).map { Int(s.rgba[$0]) }.sorted()
        return values[values.count / 2]
    }

    @Test func mtfIdentities() {
        #expect(abs(AutoStretch.mtf(0.5, 0.3) - 0.3) < 1e-12)
        #expect(AutoStretch.mtf(0.2, 0) == 0)
        #expect(AutoStretch.mtf(0.2, 1) == 1)
    }

    @Test func paramsMapMedianToTarget() {
        let p = AutoStretch.params(median: 0.1, mad: 0.005)
        let x0 = (0.1 - p.shadows) / (1 - p.shadows)
        #expect(abs(AutoStretch.mtf(p.midtones, x0) - 0.25) < 1e-9)
        #expect(abs(p.shadows - (0.1 - 2.8 * 1.4826 * 0.005)) < 1e-12)
    }

    @Test func stretchedBackgroundLandsNearQuarter() {
        let plane = Self.noisyPlane(count: 200 * 200, mean: 0.1 * 65535, sigma: 0.01 * 65535, seed: 1)
        let image = PlanarImage(width: 200, height: 200, binFactor: 1, planes: [plane])
        let s = AutoStretch.stretch(image, normalization: 65535, linked: true, enabled: true)
        #expect(abs(Self.byteMedian(s, channel: 0) - 64) <= 2)
        #expect(s.rgba[0] == s.rgba[1] && s.rgba[1] == s.rgba[2])
        #expect(s.rgba[3] == 255)
    }

    @Test func unlinkedEqualisesChannelsLinkedDoesNot() {
        let n = 150 * 150
        let planes = [0.095, 0.10, 0.105].enumerated().map { i, m in
            Self.noisyPlane(count: n, mean: m * 65535, sigma: 0.005 * 65535, seed: UInt64(10 + i))
        }
        let image = PlanarImage(width: 150, height: 150, binFactor: 2, planes: planes)
        let unlinked = AutoStretch.stretch(image, normalization: 65535, linked: false, enabled: true)
        for c in 0..<3 { #expect(abs(Self.byteMedian(unlinked, channel: c) - 64) <= 3) }
        let linked = AutoStretch.stretch(image, normalization: 65535, linked: true, enabled: true)
        #expect(Self.byteMedian(linked, channel: 0) < Self.byteMedian(linked, channel: 1))
        #expect(Self.byteMedian(linked, channel: 1) < Self.byteMedian(linked, channel: 2))
    }

    @Test func disabledIsLinear() {
        let image = PlanarImage(width: 1, height: 1, binFactor: 1, planes: [[0.5 * 65535]])
        let s = AutoStretch.stretch(image, normalization: 65535, linked: true, enabled: false)
        #expect(abs(Int(s.rgba[0]) - 128) <= 1)
    }

    @Test func cgImageAndHistogram() throws {
        let plane = Self.noisyPlane(count: 64 * 32, mean: 3000, sigma: 100, seed: 3)
        let image = PlanarImage(width: 64, height: 32, binFactor: 1, planes: [plane])
        let s = AutoStretch.stretch(image, normalization: 65535, linked: true, enabled: true)
        let cg = try #require(AutoStretch.cgImage(s))
        #expect(cg.width == 64 && cg.height == 32)
        let h = DisplayHistogram(s, isColor: false)
        #expect(h.channels.count == 1)
        #expect(h.channels[0].reduce(0, +) == 64 * 32)
    }
}
