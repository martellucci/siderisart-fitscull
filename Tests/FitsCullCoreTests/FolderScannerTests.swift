import FitsCullCore
import Foundation
import Testing

@Suite struct FolderScannerTests {
    static func frame(date: String) -> Data {
        FITSFixture.image(bitpix: 16, width: 2, height: 2, pixels: [1, 2, 3, 4], bzero: 32768,
                          extra: [FITSFixture.kv("DATE-OBS", "'\(date)'"), FITSFixture.kv("IMAGETYP", "'Light'")])
    }

    @Test func scanKeepsBadFilesWithReason() throws {
        let dir = try FITSFixture.tempDirectory()
        try FITSFixture.write(Self.frame(date: "2025-12-12T23:00:00"), name: "a.fits", in: dir)
        try FITSFixture.write(Self.frame(date: "2025-12-12T22:00:00"), name: "b.FIT", in: dir)
        try FITSFixture.write(Data(repeating: 0x41, count: 100), name: "d.fts", in: dir)
        try FITSFixture.write(Data("note".utf8), name: "c.txt", in: dir)
        try FITSFixture.write(Self.frame(date: "2025-12-12T21:00:00"), name: ".hidden.fits", in: dir)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub.fits"), withIntermediateDirectories: true)

        let scanned = try FolderScanner.scan(dir)
        #expect(scanned.map { $0.file.url.lastPathComponent } == ["b.FIT", "a.fits", "d.fts"])
        #expect(scanned[0].meta?.imageType == .light)
        #expect(scanned[0].file.size == 5760)
        #expect(scanned[2].meta == nil)
        #expect(scanned[2].headerError == "not a FITS file")
    }

    @Test func emptyFolder() throws {
        #expect(try FolderScanner.scan(try FITSFixture.tempDirectory()).isEmpty)
    }

    @Test func missingFolderThrows() {
        #expect(throws: (any Error).self) {
            try FolderScanner.scan(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))
        }
    }

    @Test func userMessages() {
        #expect(UserMessage.from(FITSError.truncatedData) == "truncated file (interrupted copy?)")
    }
}
