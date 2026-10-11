import Foundation

/// Metriche già calcolate, salvate in JSON; chiave = percorso, valide solo se dimensione e data coincidono.
public final class MetricsCache: @unchecked Sendable {
    struct Entry: Codable {
        let size: Int64
        let modified: Double
        let analysis: FrameAnalysis
    }

    /// v2: metriche stellari opzionali (le analisi v1 di dark/flat contenevano stelle spurie).
    public static let fileName = "metrics-v2.json"

    private let fileURL: URL
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var dirty = false

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent(Self.fileName)
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? Self.makeDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        }
    }

    public static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FitsCull", isDirectory: true)
    }

    public func lookup(_ file: FrameFile) -> FrameAnalysis? {
        lock.withLock {
            guard let entry = entries[file.url.path], entry.size == file.size,
                  entry.modified == file.modified.timeIntervalSince1970 else { return nil }
            return entry.analysis
        }
    }

    public func store(_ analysis: FrameAnalysis, for file: FrameFile) {
        lock.withLock {
            entries[file.url.path] = Entry(size: file.size, modified: file.modified.timeIntervalSince1970, analysis: analysis)
            dirty = true
        }
    }

    public func remove(_ url: URL) {
        lock.withLock {
            entries[url.path] = nil
            dirty = true
        }
    }

    /// Scrive su disco solo se ci sono modifiche.
    public func save() throws {
        let snapshot: [String: Entry]? = lock.withLock { dirty ? entries : nil }
        guard let snapshot else { return }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.makeEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
        lock.withLock { dirty = false }
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return decoder
    }
}
