import FitsCullCore
import Foundation
import Testing

@Suite struct FrameMetaTests {
    @Test func mapsASIAIRHeader() throws {
        let meta = FrameMeta(header: try FITSHeader.parse(FITSFixture.header(HeaderFixtures.asiair)))
        #expect(meta.width == 6248 && meta.height == 4176)
        #expect(meta.exposure == 120)
        #expect(meta.gain == 100)
        #expect(meta.offset == 50)
        #expect(abs((meta.sensorTemp ?? 0) + 20.1) < 0.001)
        #expect(meta.setTemp == -20)
        #expect(meta.object == "M 42")
        #expect(meta.imageType == .light)
        #expect(meta.bayerPattern == "RGGB")
        #expect(meta.binning == 1)
        #expect(meta.instrument == "ZWO ASI2600MC Pro")
        #expect(abs((meta.pixelScale ?? 0) - 1.88242) < 0.001)
        let expected = HeaderFixtures.utc(2025, 12, 12, 21, 36, 14).addingTimeInterval(0.004013)
        #expect(abs(meta.dateObs!.timeIntervalSince(expected)) < 1e-4)
    }

    @Test func mapsNINAHeader() throws {
        let meta = FrameMeta(header: try FITSHeader.parse(FITSFixture.header(HeaderFixtures.nina)))
        #expect(meta.imageType == .dark)
        #expect(meta.exposure == 300)
        #expect(meta.focalLengthMM == 800)
        #expect(meta.sensorTemp == -10)
        #expect(abs((meta.airmass ?? 0) - 1.58937) < 1e-4)
        #expect(abs((meta.pixelScale ?? 0) - 0.96944) < 0.001)
        let expected = HeaderFixtures.utc(2026, 3, 20, 17, 25, 1).addingTimeInterval(0.3361782)
        #expect(abs(meta.dateObs!.timeIntervalSince(expected)) < 1e-4)
    }

    @Test func missingOpticsGiveNoScale() throws {
        let meta = FrameMeta(header: try FITSHeader.parse(FITSFixture.header([
            FITSFixture.kv("SIMPLE", "T"), FITSFixture.kv("XPIXSZ", "3.76"),
        ])))
        #expect(meta.pixelScale == nil)
        #expect(meta.bayerPattern == nil)
        #expect(meta.imageType == .unknown)
    }

    @Test(arguments: [
        ("Light Frame", ImageType.light), ("DARK", .dark), ("Flat Field", .flat), ("Bias Frame", .bias),
        ("DARKFLAT", .darkFlat), ("Dark Flat", .darkFlat), ("whatever", .unknown),
    ])
    func imageTypeMapping(value: String, expected: ImageType) {
        #expect(ImageType(fitsValue: value) == expected)
    }

    @Test func onlyLightAndUnknownHaveStars() {
        #expect(ImageType.light.hasStars)
        #expect(ImageType.unknown.hasStars)
        for type in [ImageType.dark, .flat, .bias, .darkFlat] { #expect(!type.hasStars) }
    }

    @Test func rejectsInvalidBayerPattern() throws {
        let meta = FrameMeta(header: try FITSHeader.parse(FITSFixture.header([
            FITSFixture.kv("SIMPLE", "T"), FITSFixture.kv("BAYERPAT", "'XYZW'"),
        ])))
        #expect(meta.bayerPattern == nil)
    }

    @Test func imageTypeLabelsAreEnglish() {
        #expect(ImageType.allCases.map(\.label) == ["Light", "Dark", "Flat", "Bias", "Dark flat", "Unknown"])
    }
}
