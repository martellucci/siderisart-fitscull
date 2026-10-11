import Foundation

public protocol FileTrashing: Sendable {
    func trashItem(at url: URL) throws
}

public struct SystemTrash: FileTrashing {
    public init() {}

    public func trashItem(at url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}

public struct TrashReport: Sendable, Equatable {
    public var trashed: [URL] = []
    /// Volume senza Cestino (tipico delle condivisioni SMB).
    public var trashUnavailable: [URL] = []
    public var failed: [URL: String] = [:]
}

public struct FileOpReport: Sendable, Equatable {
    public var done: [URL] = []
    public var failed: [URL: String] = [:]
}

public struct TrashService: Sendable {
    public static let rejectFolderName = "_scartati"

    private let trasher: FileTrashing

    public init(trasher: FileTrashing = SystemTrash()) {
        self.trasher = trasher
    }

    public func moveToTrash(_ urls: [URL]) -> TrashReport {
        var report = TrashReport()
        for url in urls {
            do {
                try trasher.trashItem(at: url)
                report.trashed.append(url)
            } catch let error as CocoaError where error.code == .featureUnsupported {
                report.trashUnavailable.append(url)
            } catch {
                report.failed[url] = error.localizedDescription
            }
        }
        return report
    }

    /// Sposta in `_scartati/` accanto a ogni file, senza sovrascrivere ("nome 2.fits", …).
    public func moveToRejectFolder(_ urls: [URL]) -> FileOpReport {
        let fm = FileManager.default
        var report = FileOpReport()
        for url in urls {
            do {
                let folder = url.deletingLastPathComponent().appendingPathComponent(Self.rejectFolderName, isDirectory: true)
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                var destination = folder.appendingPathComponent(url.lastPathComponent)
                var n = 2
                while fm.fileExists(atPath: destination.path) {
                    destination = folder.appendingPathComponent(
                        "\(url.deletingPathExtension().lastPathComponent) \(n).\(url.pathExtension)")
                    n += 1
                }
                try fm.moveItem(at: url, to: destination)
                report.done.append(url)
            } catch {
                report.failed[url] = error.localizedDescription
            }
        }
        return report
    }

    public func deletePermanently(_ urls: [URL]) -> FileOpReport {
        var report = FileOpReport()
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
                report.done.append(url)
            } catch {
                report.failed[url] = error.localizedDescription
            }
        }
        return report
    }
}
