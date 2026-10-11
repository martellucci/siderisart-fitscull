import Foundation

public struct FrameFile: Sendable, Hashable, Codable {
    public let url: URL
    public let size: Int64
    public let modified: Date

    public init(url: URL, size: Int64, modified: Date) {
        self.url = url
        self.size = size
        self.modified = modified
    }
}

public struct ScannedFrame: Sendable, Identifiable {
    public var id: URL { file.url }
    public let file: FrameFile
    public let header: FITSHeader?
    public let meta: FrameMeta?
    /// Motivo leggibile se l'header non è leggibile.
    public let headerError: String?
}

public enum UserMessage {
    public static func from(_ error: Error) -> String {
        (error as? FITSError)?.description ?? error.localizedDescription
    }
}

public enum FolderScanner {
    public static let extensions: Set<String> = ["fit", "fits", "fts"]

    /// File FITS della cartella (non ricorsivo, senza nascosti), ordinati per nome.
    public static func listFiles(in folder: URL) throws -> [FrameFile] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        let items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                options: [.skipsHiddenFiles])
        return try items.compactMap { url -> FrameFile? in
            guard extensions.contains(url.pathExtension.lowercased()) else { return nil }
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { return nil }
            return FrameFile(url: url, size: Int64(values.fileSize ?? 0),
                             modified: values.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
    }

    /// Elenco con header letti (solo i primi blocchi di ogni file), in ordine cronologico.
    public static func scan(_ folder: URL) throws -> [ScannedFrame] {
        try listFiles(in: folder).map { file in
            do {
                let header = try FITSReader.readHeader(url: file.url)
                return ScannedFrame(file: file, header: header, meta: FrameMeta(header: header), headerError: nil)
            } catch {
                return ScannedFrame(file: file, header: nil, meta: nil, headerError: UserMessage.from(error))
            }
        }
        .sorted(by: chronological)
    }

    static func chronological(_ a: ScannedFrame, _ b: ScannedFrame) -> Bool {
        if let da = a.meta?.dateObs, let db = b.meta?.dateObs, da != db { return da < db }
        return a.file.url.lastPathComponent.localizedStandardCompare(b.file.url.lastPathComponent) == .orderedAscending
    }
}
