import FitsCullCore
import Foundation
import Testing

/// Simula il Cestino: i nomi in `unsupported` falliscono come su un NAS SMB.
struct FakeTrash: FileTrashing {
    let unsupported: Set<String>
    let failing: Set<String>
    let trashDirectory: URL

    func trashItem(at url: URL) throws {
        if unsupported.contains(url.lastPathComponent) { throw CocoaError(.featureUnsupported) }
        if failing.contains(url.lastPathComponent) { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.moveItem(at: url, to: trashDirectory.appendingPathComponent(url.lastPathComponent))
    }
}

@Suite struct TrashServiceTests {
    static func files(_ names: [String]) throws -> (dir: URL, urls: [URL]) {
        let dir = try FITSFixture.tempDirectory()
        let urls = try names.map { try FITSFixture.write(Data("x".utf8), name: $0, in: dir) }
        return (dir, urls)
    }

    @Test func trashesAll() throws {
        let (_, urls) = try Self.files(["a.fits", "b.fits"])
        let service = TrashService(trasher: FakeTrash(unsupported: [], failing: [], trashDirectory: try FITSFixture.tempDirectory()))
        let report = service.moveToTrash(urls)
        #expect(report.trashed == urls)
        #expect(report.trashUnavailable.isEmpty && report.failed.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: urls[0].path))
    }

    @Test func reportsTrashUnavailable() throws {
        let (_, urls) = try Self.files(["a.fits", "b.fits", "c.fits"])
        let fake = FakeTrash(unsupported: ["b.fits"], failing: ["c.fits"], trashDirectory: try FITSFixture.tempDirectory())
        let report = TrashService(trasher: fake).moveToTrash(urls)
        #expect(report.trashed == [urls[0]])
        #expect(report.trashUnavailable == [urls[1]])
        #expect(report.failed.keys.sorted { $0.path < $1.path } == [urls[2]])
        #expect(FileManager.default.fileExists(atPath: urls[1].path))
    }

    @Test func movesToRejectFolderWithoutOverwriting() throws {
        let (dir, urls) = try Self.files(["a.fits"])
        #expect(TrashService.rejectFolderName == "_rejected")
        let reject = dir.appendingPathComponent(TrashService.rejectFolderName)
        try FileManager.default.createDirectory(at: reject, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: reject.appendingPathComponent("a.fits"))
        let report = TrashService().moveToRejectFolder(urls)
        #expect(report.done == urls)
        #expect(report.failed.isEmpty)
        #expect(FileManager.default.fileExists(atPath: reject.appendingPathComponent("a 2.fits").path))
        #expect(try String(contentsOf: reject.appendingPathComponent("a.fits"), encoding: .utf8) == "old")
    }

    @Test func deletesPermanently() throws {
        let (_, urls) = try Self.files(["a.fits"])
        let missing = urls[0].deletingLastPathComponent().appendingPathComponent("missing.fits")
        let report = TrashService().deletePermanently(urls + [missing])
        #expect(report.done == urls)
        #expect(report.failed.keys.contains(missing))
        #expect(!FileManager.default.fileExists(atPath: urls[0].path))
    }
}
