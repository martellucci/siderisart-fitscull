import FitsCullCore
import Foundation
import Testing

@Suite struct FITSHeaderTests {
    @Test func parsesTypedValuesAndEnd() throws {
        let data = FITSFixture.header([
            FITSFixture.kv("SIMPLE", "T"),
            FITSFixture.kv("BITPIX", "16 / number of bits"),
            FITSFixture.kv("NAXIS", "2"),
            FITSFixture.kv("IMAGETYP", "'Light   '           / Type of image"),
            FITSFixture.kv("EXPOSURE", "120. / Exposure time"),
            FITSFixture.kv("A_0_2", "7.51612418226E-08"),
            "COMMENT   just a comment",
        ])
        let h = try FITSHeader.parse(data)
        #expect(h.byteLength == 2880)
        #expect(h.bool("SIMPLE") == true)
        #expect(h.int("BITPIX") == 16)
        #expect(h.string("IMAGETYP") == "Light")
        #expect(h.double("EXPOSURE") == 120)
        #expect(h.int("EXPOSURE") == 120)
        #expect(abs((h.double("A_0_2") ?? 0) - 7.51612418226e-8) < 1e-20)
        #expect(h.cards.first { $0.key == "BITPIX" }?.comment == "number of bits")
        #expect(h["COMMENT"] == nil)
        #expect(h.cards.count == 7)
    }

    @Test func headerSpanningTwoBlocks() throws {
        var cards = [FITSFixture.kv("SIMPLE", "T")]
        for i in 0..<40 { cards.append(FITSFixture.kv("K\(i)", "\(i)")) }
        let h = try FITSHeader.parse(FITSFixture.header(cards))
        #expect(h.byteLength == 5760)
        #expect(h.int("K39") == 39)
    }

    @Test func escapedQuoteInString() throws {
        let h = try FITSHeader.parse(FITSFixture.header([
            FITSFixture.kv("SIMPLE", "T"),
            FITSFixture.kv("OBSERVER", "'O''Neil' / name"),
        ]))
        #expect(h.string("OBSERVER") == "O'Neil")
        #expect(h.cards.last?.comment == "name")
    }

    @Test func rejectsNonFITS() {
        #expect(throws: FITSError.notFITS) {
            try FITSHeader.parse(Data(String(repeating: "X", count: 2880).utf8))
        }
    }

    @Test func missingEndIsTruncated() {
        let text = FITSFixture.card(FITSFixture.kv("SIMPLE", "T")) + FITSFixture.card(FITSFixture.kv("BITPIX", "16"))
        #expect(throws: FITSError.truncatedHeader) {
            try FITSHeader.parse(Data(text.utf8))
        }
    }

    @Test func errorsHaveItalianDescriptions() {
        #expect(FITSError.truncatedData.description == "file troncato (copia interrotta?)")
        #expect(FITSError.unsupported("NAXIS = 3").description == "non supportato: NAXIS = 3")
    }
}
