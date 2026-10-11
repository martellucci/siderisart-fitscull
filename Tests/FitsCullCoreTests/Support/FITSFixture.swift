import Foundation

/// Costruisce file FITS sintetici per i test.
enum FITSFixture {
    static func card(_ s: String) -> String {
        s.padding(toLength: 80, withPad: " ", startingAt: 0)
    }

    static func kv(_ key: String, _ value: String) -> String {
        key.padding(toLength: 8, withPad: " ", startingAt: 0) + "= " + value
    }

    /// Header completo: card + END, riempito a multipli di 2880 byte.
    static func header(_ cards: [String]) -> Data {
        var text = cards.map(card).joined() + card("END")
        let remainder = text.count % 2880
        if remainder != 0 { text += String(repeating: " ", count: 2880 - remainder) }
        return Data(text.utf8)
    }

    /// File FITS completo. `pixels` sono valori fisici (dopo BZERO/BSCALE), riga per riga.
    static func image(bitpix: Int, width: Int, height: Int, pixels: [Double],
                      bzero: Double = 0, bscale: Double = 1, extra: [String] = []) -> Data {
        var cards = [kv("SIMPLE", "T"), kv("BITPIX", "\(bitpix)"), kv("NAXIS", "2"),
                     kv("NAXIS1", "\(width)"), kv("NAXIS2", "\(height)")]
        if bzero != 0 { cards.append(kv("BZERO", "\(bzero)")) }
        if bscale != 1 { cards.append(kv("BSCALE", "\(bscale)")) }
        cards += extra
        var data = header(cards)
        var body = Data()
        for p in pixels {
            let raw = ((p - bzero) / bscale).rounded()
            switch bitpix {
            case 8:
                body.append(UInt8(max(0, min(255, raw))))
            case 16:
                withUnsafeBytes(of: Int16(max(-32768, min(32767, raw))).bigEndian) { body.append(contentsOf: $0) }
            case 32:
                withUnsafeBytes(of: Int32(raw).bigEndian) { body.append(contentsOf: $0) }
            case -32:
                withUnsafeBytes(of: Float((p - bzero) / bscale).bitPattern.bigEndian) { body.append(contentsOf: $0) }
            case -64:
                withUnsafeBytes(of: ((p - bzero) / bscale).bitPattern.bigEndian) { body.append(contentsOf: $0) }
            default:
                fatalError("BITPIX non gestito nel fixture")
            }
        }
        let remainder = body.count % 2880
        if remainder != 0 { body.append(Data(count: 2880 - remainder)) }
        data.append(body)
        return data
    }

    static func tempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FitsCullTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    static func write(_ data: Data, name: String = "frame.fits", in directory: URL? = nil) throws -> URL {
        let dir = try directory ?? tempDirectory()
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}
