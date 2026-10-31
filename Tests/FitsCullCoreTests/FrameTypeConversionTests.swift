import FitsCullCore
import Foundation
import Testing

@Suite struct FrameTypeConversionTests {
    static let asiair = "Light_M31_120.0s_Bin1_2600MM_gain100_20231015-213045_-10.0C_0001.fit"

    static func frame(type: String? = "'Light'", extra: [String] = []) -> Data {
        let typeCard = type.map { [FITSFixture.kv("IMAGETYP", "\($0)               / Type of exposure")] } ?? []
        return FITSFixture.image(bitpix: 16, width: 2, height: 2, pixels: [1, 2, 3, 4], bzero: 32768,
                                 extra: [FITSFixture.kv("EXPTIME", "120.0")] + typeCard + extra)
    }

    static func cards(_ data: Data) throws -> [FITSCard] {
        try FITSHeader.parse(data).cards
    }

    // MARK: - Nome del file

    @Test func renamesASIAIRPrefix() {
        #expect(FrameTypeConversion.fileName(Self.asiair, from: .light, to: .dark)
                == "Dark_M31_120.0s_Bin1_2600MM_gain100_20231015-213045_-10.0C_0001.fit")
        #expect(FrameTypeConversion.fileName("Flat_120.0s_0001.fit", from: .flat, to: .light) == "Light_120.0s_0001.fit")
    }

    @Test func renameKeepsCaseStyle() {
        #expect(FrameTypeConversion.fileName("2023-10-15_LIGHT_0001.fits", from: .light, to: .flat)
                == "2023-10-15_FLAT_0001.fits")
        #expect(FrameTypeConversion.fileName("m31_dark_0001.fits", from: .dark, to: .light) == "m31_light_0001.fits")
    }

    /// Senza il tipo nel nome (come parola intera) il nuovo tipo va davanti.
    @Test func renamePrefixesWhenTypeIsMissing() {
        #expect(FrameTypeConversion.fileName("M31_0001.fit", from: .light, to: .dark) == "Dark_M31_0001.fit")
        #expect(FrameTypeConversion.fileName("Lightning_0001.fit", from: .light, to: .dark) == "Dark_Lightning_0001.fit")
    }

    // MARK: - Header

    @Test func rewritesImageTypeKeepingEverythingElse() throws {
        let original = Self.frame()
        let converted = try FrameTypeConversion.converted(original, to: .dark)
        #expect(converted.count == original.count)
        let card = try #require(try Self.cards(converted).first { $0.key == "IMAGETYP" })
        #expect(card.value == .string("Dark"))
        #expect(card.comment == "Type of exposure")
        #expect(try FrameMeta(header: FITSHeader.parse(converted)).imageType == .dark)
        let header = try FITSHeader.parse(original).byteLength
        #expect(converted[header...] == original[header...])
        let others = { (data: Data) in try Self.cards(data).filter { $0.key != "IMAGETYP" }.map(\.raw) }
        #expect(try others(converted) == others(original))
    }

    @Test func rewritesFrameKeywordAndKeepsValueCase() throws {
        let original = Self.frame(type: "'LIGHT'", extra: [FITSFixture.kv("FRAME", "'Light'")])
        let cards = try Self.cards(FrameTypeConversion.converted(original, to: .flat))
        #expect(cards.first { $0.key == "IMAGETYP" }?.value == .string("FLAT"))
        #expect(cards.first { $0.key == "FRAME" }?.value == .string("Flat"))
    }

    /// La card cambia: un CHECKSUM non sarebbe più valido (DATASUM sì, i dati restano gli stessi).
    @Test func dropsChecksum() throws {
        let original = Self.frame(extra: [FITSFixture.kv("CHECKSUM", "'9a3Ja93H9a3Ha93H'"), FITSFixture.kv("DATASUM", "'1234'")])
        let keys = try Self.cards(FrameTypeConversion.converted(original, to: .dark)).map(\.key)
        #expect(!keys.contains("CHECKSUM"))
        #expect(keys.contains("DATASUM"))
    }

    /// 35 card + END riempiono il blocco: la card aggiunta richiede un secondo blocco di header.
    @Test func insertsMissingImageTypeGrowingTheHeader() throws {
        let filler = (0..<28).map { FITSFixture.kv(String(format: "KEY%02d", $0), "\($0)") }
        let original = Self.frame(type: nil, extra: filler)
        #expect(try FITSHeader.parse(original).byteLength == 2880)
        let converted = try FrameTypeConversion.converted(original, to: .flat)
        let header = try FITSHeader.parse(converted)
        #expect(header.byteLength == 5760)
        #expect(header.string("IMAGETYP") == "Flat")
        #expect(converted.count == original.count + 2880)
        #expect(try FITSReader.decode(converted).pixels == FITSReader.decode(original).pixels)
    }

    // MARK: - File

    @Test func convertWritesCopyNextToOriginal() throws {
        let dir = try FITSFixture.tempDirectory()
        let source = try FITSFixture.write(Self.frame(), name: Self.asiair, in: dir)
        let copy = try FrameTypeConversion.convert(source, to: .dark)
        #expect(copy.deletingLastPathComponent().standardizedFileURL == dir.standardizedFileURL)
        #expect(copy.lastPathComponent.hasPrefix("Dark_M31_120.0s"))
        #expect(try FrameMeta(header: FITSReader.readHeader(url: copy)).imageType == .dark)
        #expect(try Data(contentsOf: source) == Self.frame())
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).count == 2)
    }

    @Test func convertNeverOverwrites() throws {
        let dir = try FITSFixture.tempDirectory()
        let source = try FITSFixture.write(Self.frame(), name: "Light_0001.fit", in: dir)
        let existing = try FITSFixture.write(Data("keep".utf8), name: "Dark_0001.fit", in: dir)
        #expect(throws: FrameTypeConversion.Failure.destinationExists("Dark_0001.fit")) {
            try FrameTypeConversion.convert(source, to: .dark)
        }
        #expect(try Data(contentsOf: existing) == Data("keep".utf8))
    }

    @Test func convertRejectsUnsupportedOrSameType() throws {
        let dir = try FITSFixture.tempDirectory()
        let bias = try FITSFixture.write(Self.frame(type: "'Bias'"), name: "Bias_0001.fit", in: dir)
        let light = try FITSFixture.write(Self.frame(), name: "Light_0001.fit", in: dir)
        #expect(throws: FrameTypeConversion.Failure.unsupportedType("Bias")) {
            try FrameTypeConversion.convert(bias, to: .dark)
        }
        #expect(throws: FrameTypeConversion.Failure.sameType) { try FrameTypeConversion.convert(light, to: .light) }
        #expect(throws: FrameTypeConversion.Failure.unsupportedType("Bias")) {
            try FrameTypeConversion.convert(light, to: .bias)
        }
    }

    // MARK: - Cartella

    @Test func candidatesAreOnlyFilesOfTheChosenType() throws {
        let dir = try FITSFixture.tempDirectory()
        try FITSFixture.write(Self.frame(), name: "Light_0001.fit", in: dir)
        try FITSFixture.write(Self.frame(), name: "Light_0002.fit", in: dir)
        try FITSFixture.write(Self.frame(type: "'Flat'"), name: "Flat_0001.fit", in: dir)
        let counts = try FrameTypeConversion.count(in: dir)
        #expect(counts == [.light: 2, .flat: 1])
        let lights = try FrameTypeConversion.candidates(in: dir, of: .light).map(\.lastPathComponent)
        #expect(lights == ["Light_0001.fit", "Light_0002.fit"])
    }

    @Test func convertAllReportsSkippedAndConverted() throws {
        let dir = try FITSFixture.tempDirectory()
        let a = try FITSFixture.write(Self.frame(), name: "Light_0001.fit", in: dir)
        let b = try FITSFixture.write(Self.frame(), name: "Light_0002.fit", in: dir)
        try FITSFixture.write(Data("keep".utf8), name: "Dark_0002.fit", in: dir)
        let report = FrameTypeConversion.convertAll([a, b], to: .dark)
        #expect(report.converted.map(\.lastPathComponent) == ["Dark_0001.fit"])
        #expect(report.skipped == [b])
        #expect(report.failed.isEmpty)
    }
}
