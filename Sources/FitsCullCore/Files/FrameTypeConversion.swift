import Foundation

/// Cambio di tipo (Light, Dark, Flat) di frame salvati col tipo sbagliato, es. dark ripresi con l'ASIAIR
/// rimasto su Light. Scrive una copia accanto all'originale con IMAGETYP (e FRAME) e prefisso del nome
/// aggiornati; header restante e dati restano identici byte per byte. L'originale non viene toccato.
public enum FrameTypeConversion {
    public static let types: [ImageType] = [.light, .dark, .flat]

    public enum Failure: Error, Equatable, Sendable, CustomStringConvertible {
        case unsupportedType(String)
        case sameType
        case destinationExists(String)

        public var description: String {
            switch self {
            case .unsupportedType(let type): "\(type) frames cannot be converted (only Light, Dark and Flat)"
            case .sameType: "the file is already of that type"
            case .destinationExists(let name): "\"\(name)\" already exists"
            }
        }
    }

    public struct Report: Sendable, Equatable {
        /// Copie create.
        public var converted: [URL] = []
        /// Originali saltati: esiste già un file col nuovo nome.
        public var skipped: [URL] = []
        public var failed: [URL: String] = [:]
    }

    // MARK: - Nome del file

    /// Sostituisce il tipo nel nome (parola intera, stesso stile di maiuscole); se manca lo mette davanti.
    public static func fileName(_ name: String, from: ImageType, to: ImageType) -> String {
        let word = from.label
        var search = name.startIndex..<name.endIndex
        while let range = name.range(of: word, options: .caseInsensitive, range: search) {
            let before = range.lowerBound == name.startIndex ? nil : name[name.index(before: range.lowerBound)]
            let after = range.upperBound == name.endIndex ? nil : name[range.upperBound]
            if !(before?.isLetter ?? false) && !(after?.isLetter ?? false) {
                return name.replacingCharacters(in: range, with: matchingCase(to.label, like: String(name[range])))
            }
            search = range.upperBound..<name.endIndex
        }
        return to.label + "_" + name
    }

    private static func matchingCase(_ word: String, like sample: String) -> String {
        if sample == sample.uppercased() { return word.uppercased() }
        if sample == sample.lowercased() { return word.lowercased() }
        return word
    }

    // MARK: - Header

    /// File con il nuovo tipo in IMAGETYP e FRAME (aggiunge IMAGETYP se manca). Toglie CHECKSUM, che non
    /// sarebbe più valido; DATASUM resta corretto perché i dati non cambiano.
    public static func converted(_ data: Data, to type: ImageType) throws -> Data {
        let header = try FITSHeader.parse(data)
        var cards: [Data] = []
        var hasImageType = false
        var offset = data.startIndex
        while true {
            let raw = data[offset ..< offset + FITSHeader.cardSize]
            offset += FITSHeader.cardSize
            let card = FITSHeader.parseCard(String(decoding: raw, as: UTF8.self))
            if card.key == "END" { break }
            switch (card.key, card.value) {
            case ("IMAGETYP", .string(let value)?), ("FRAME", .string(let value)?):
                hasImageType = hasImageType || card.key == "IMAGETYP"
                cards.append(stringCard(card.key, matchingCase(type.label, like: value), comment: card.comment))
            case ("CHECKSUM", _):
                continue
            default:
                cards.append(Data(raw))
            }
        }
        if !hasImageType { cards.append(stringCard("IMAGETYP", type.label, comment: "Type of exposure")) }
        var result = cards.reduce(into: Data()) { $0.append($1) }
        result.append(Data("END".padding(toLength: FITSHeader.cardSize, withPad: " ", startingAt: 0).utf8))
        let remainder = result.count % FITSHeader.blockSize
        if remainder != 0 { result.append(Data(repeating: 0x20, count: FITSHeader.blockSize - remainder)) }
        result.append(data[(data.startIndex + header.byteLength)...])
        return result
    }

    /// Card a formato fisso: apice di chiusura almeno in colonna 20, commento da colonna 32.
    private static func stringCard(_ key: String, _ value: String, comment: String) -> Data {
        let quoted = "'" + value.padding(toLength: max(value.count, 8), withPad: " ", startingAt: 0) + "'"
        var text = key.padding(toLength: 8, withPad: " ", startingAt: 0) + "= " + quoted
        if !comment.isEmpty {
            text = text.padding(toLength: max(text.count, 30), withPad: " ", startingAt: 0) + " / " + comment
        }
        return Data(text.padding(toLength: FITSHeader.cardSize, withPad: " ", startingAt: 0).utf8)
    }

    // MARK: - File

    /// Scrive la copia convertita nella cartella dell'originale; non sovrascrive mai un file esistente.
    @discardableResult
    public static func convert(_ url: URL, to type: ImageType) throws -> URL {
        guard types.contains(type) else { throw Failure.unsupportedType(type.label) }
        let data = try Data(contentsOf: url, options: FITSReader.readingOptions)
        let current = FrameMeta(header: try FITSHeader.parse(data)).imageType
        guard types.contains(current) else { throw Failure.unsupportedType(current.label) }
        guard current != type else { throw Failure.sameType }

        let folder = url.deletingLastPathComponent()
        let name = fileName(url.lastPathComponent, from: current, to: type)
        let destination = folder.appendingPathComponent(name)
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path) else { throw Failure.destinationExists(name) }
        // Scrittura in un file nascosto e poi rinomina: niente copie a metà col nome definitivo
        // (es. NAS che si scollega). moveItem non sovrascrive.
        let partial = folder.appendingPathComponent(".\(name).converting")
        do {
            try converted(data, to: type).write(to: partial)
            try fm.moveItem(at: partial, to: destination)
        } catch {
            try? fm.removeItem(at: partial)
            if fm.fileExists(atPath: destination.path) { throw Failure.destinationExists(name) }
            throw error
        }
        return destination
    }

    // MARK: - Cartella

    /// Quanti file di ogni tipo convertibile ci sono nella cartella (solo header).
    public static func count(in folder: URL) throws -> [ImageType: Int] {
        try FolderScanner.scan(folder).reduce(into: [:]) { counts, frame in
            if let type = frame.meta?.imageType, types.contains(type) { counts[type, default: 0] += 1 }
        }
    }

    /// File della cartella del tipo indicato, in ordine di nome.
    public static func candidates(in folder: URL, of type: ImageType) throws -> [URL] {
        try FolderScanner.scan(folder).filter { $0.meta?.imageType == type }.map(\.file.url)
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public static func convertAll(_ urls: [URL], to type: ImageType) -> Report {
        var report = Report()
        for url in urls {
            do {
                report.converted.append(try convert(url, to: type))
            } catch Failure.destinationExists {
                report.skipped.append(url)
            } catch {
                report.failed[url] = UserMessage.from(error)
            }
        }
        return report
    }
}
