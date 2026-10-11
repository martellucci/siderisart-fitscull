import FitsCullCore
import Foundation
import Testing

@Suite struct StarDetectorTests {
    @Test func roundStarsCountAndFWHM() {
        let field = SyntheticField.make(width: 512, height: 512, stars: SyntheticField.grid())
        let m = StarDetector.detect(field, width: 512, height: 512, saturationLevel: 65535, arcsecPerPixel: nil)
        #expect(m.count == 64)
        let expectedFWHM = 2.3548 * 2.0
        #expect(abs((m.fwhm ?? 0) - expectedFWHM) / expectedFWHM < 0.05)
        #expect((m.eccentricity ?? 1) < 0.15)
        #expect(abs((m.hfr ?? 0) - 2.355) / 2.355 < 0.15)
        #expect(m.fwhmArcsec == nil)
    }

    @Test func elongatedStarsEccentricity() {
        let field = SyntheticField.make(width: 512, height: 512, stars: SyntheticField.grid(sigmaX: 3, sigmaY: 1.5))
        let m = StarDetector.detect(field, width: 512, height: 512, saturationLevel: nil, arcsecPerPixel: nil)
        #expect(m.count == 64)
        #expect(abs((m.eccentricity ?? 0) - 0.866) < 0.05)
    }

    @Test func gradientBackgroundStillFindsAllStars() {
        let field = SyntheticField.make(width: 512, height: 512, background: { x, y in 1000 + Double(x) + 0.5 * Double(y) },
                                        stars: SyntheticField.grid())
        #expect(StarDetector.detect(field, width: 512, height: 512, saturationLevel: nil, arcsecPerPixel: nil).count == 64)
    }

    @Test func emptyFieldHasNoStars() {
        let field = SyntheticField.make(width: 512, height: 512, stars: [])
        let m = StarDetector.detect(field, width: 512, height: 512, saturationLevel: 65535, arcsecPerPixel: 1.9)
        #expect(m == .none)
        #expect(m.fwhm == nil && m.hfr == nil && m.eccentricity == nil)
    }

    @Test func saturatedStarsAreExcluded() {
        let stars = SyntheticField.grid().enumerated().map { i, s in
            var star = s
            if i % 2 == 0 { star.amplitude = 80000 }
            return star
        }
        let field = SyntheticField.make(width: 512, height: 512, stars: stars, clip: 65535)
        #expect(StarDetector.detect(field, width: 512, height: 512, saturationLevel: 65535, arcsecPerPixel: nil).count == 32)
    }

    @Test func arcsecondsUseGivenScale() {
        let field = SyntheticField.make(width: 512, height: 512, stars: SyntheticField.grid())
        let m = StarDetector.detect(field, width: 512, height: 512, saturationLevel: nil, arcsecPerPixel: 3.76)
        #expect(abs((m.fwhmArcsec ?? 0) - (m.fwhm ?? 0) * 3.76) < 1e-9)
    }

    @Test func tinyImageDoesNotCrash() {
        #expect(StarDetector.detect([Float](repeating: 1, count: 16), width: 4, height: 4,
                                    saturationLevel: nil, arcsecPerPixel: nil) == .none)
    }
}
