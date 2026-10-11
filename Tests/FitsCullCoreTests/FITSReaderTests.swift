import FitsCullCore
import Foundation
import Testing

@Suite struct FITSReaderTests {
    @Test func reads16BitWithBZero() throws {
        let px: [Double] = [0, 1000, 32768, 65535, 12345, 50000]
        let img = try FITSReader.decode(FITSFixture.image(bitpix: 16, width: 3, height: 2, pixels: px, bzero: 32768))
        #expect(img.width == 3)
        #expect(img.height == 2)
        #expect(img.pixels == px.map(Float.init))
        #expect(img.maxRepresentable == 65535)
    }

    @Test(arguments: [8, 32, -32])
    func readsOtherBitDepths(bitpix: Int) throws {
        let px: [Double] = [0, 1, 2, 200, 100, 7]
        let img = try FITSReader.decode(FITSFixture.image(bitpix: bitpix, width: 2, height: 3, pixels: px))
        #expect(img.pixels == px.map(Float.init))
        #expect(img.bitpix == bitpix)
    }

    @Test func appliesBScale() throws {
        let img = try FITSReader.decode(FITSFixture.image(bitpix: 16, width: 2, height: 1, pixels: [10, 20], bscale: 2))
        #expect(img.pixels == [10, 20])
    }

    @Test func floatHasNoSaturationLevel() throws {
        let img = try FITSReader.decode(FITSFixture.image(bitpix: -32, width: 1, height: 1, pixels: [0.5]))
        #expect(img.maxRepresentable == nil)
        #expect(FITSFixture.image(bitpix: 8, width: 1, height: 1, pixels: [3]).count == 5760)
    }

    @Test func rejectsCubes() throws {
        var data = FITSFixture.header([
            FITSFixture.kv("SIMPLE", "T"), FITSFixture.kv("BITPIX", "16"), FITSFixture.kv("NAXIS", "3"),
            FITSFixture.kv("NAXIS1", "2"), FITSFixture.kv("NAXIS2", "2"), FITSFixture.kv("NAXIS3", "3"),
        ])
        data.append(Data(count: 2880))
        let error = #expect(throws: FITSError.self) { try FITSReader.decode(data) }
        #expect(error == .unsupported("NAXIS = 3"))
    }

    @Test func rejectsEmptyPrimaryHDU() {
        let data = FITSFixture.header([
            FITSFixture.kv("SIMPLE", "T"), FITSFixture.kv("BITPIX", "8"), FITSFixture.kv("NAXIS", "0"),
            FITSFixture.kv("EXTEND", "T"),
        ])
        let error = #expect(throws: FITSError.self) { try FITSReader.decode(data) }
        #expect(error == .unsupported("nessuna immagine nell'HDU primaria (file compresso?)"))
    }

    @Test func rejectsDoublePrecision() {
        let data = FITSFixture.image(bitpix: -64, width: 1, height: 1, pixels: [1])
        let error = #expect(throws: FITSError.self) { try FITSReader.decode(data) }
        #expect(error == .unsupported("BITPIX = -64"))
    }

    @Test func truncatedDataIsReported() {
        let full = FITSFixture.image(bitpix: 16, width: 3, height: 2, pixels: [1, 2, 3, 4, 5, 6], bzero: 32768)
        #expect(throws: FITSError.truncatedData) {
            try FITSReader.decode(full.prefix(2880 + 6))
        }
    }

    @Test func readHeaderMatchesFullRead() throws {
        let data = FITSFixture.image(bitpix: 16, width: 3, height: 2, pixels: [1, 2, 3, 4, 5, 6], bzero: 32768,
                                     extra: [FITSFixture.kv("OBJECT", "'M 42'")])
        let url = try FITSFixture.write(data)
        let header = try FITSReader.readHeader(url: url)
        #expect(header == (try FITSReader.read(url: url)).header)
        #expect(header.string("OBJECT") == "M 42")
    }

    @Test func readHeaderOfNonFITSThrows() throws {
        let url = try FITSFixture.write(Data(repeating: 0x41, count: 4000), name: "bad.fits")
        #expect(throws: FITSError.notFITS) { try FITSReader.readHeader(url: url) }
    }
}
