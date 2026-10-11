import Foundation

public struct FITSImage: Sendable {
    public let header: FITSHeader
    public let width: Int
    public let height: Int
    public let bitpix: Int
    /// Valori fisici (BZERO/BSCALE applicati), riga per riga; la riga 0 è la prima del file (in alto).
    public let pixels: [Float]
    /// Massimo valore fisico rappresentabile dal tipo intero; nil per dati in virgola mobile.
    public let maxRepresentable: Float?

    public init(header: FITSHeader, width: Int, height: Int, bitpix: Int, pixels: [Float], maxRepresentable: Float?) {
        self.header = header
        self.width = width
        self.height = height
        self.bitpix = bitpix
        self.pixels = pixels
        self.maxRepresentable = maxRepresentable
    }
}

public enum FITSReader {
    /// Mappa in memoria solo i volumi locali: su un volume di rete una disconnessione durante la lettura
    /// di un file mappato terminerebbe l'app (SIGBUS).
    public static let readingOptions: Data.ReadingOptions = .mappedIfSafe

    /// Legge solo i blocchi dell'header (veloce anche su NAS).
    public static func readHeader(url: URL) throws -> FITSHeader {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        for _ in 0..<200 {
            guard let block = try handle.read(upToCount: FITSHeader.blockSize), !block.isEmpty else { break }
            data.append(block)
            do {
                return try FITSHeader.parse(data)
            } catch FITSError.truncatedHeader {
                continue
            }
        }
        throw FITSError.truncatedHeader
    }

    public static func read(url: URL) throws -> FITSImage {
        try decode(Data(contentsOf: url, options: readingOptions))
    }

    public static func decode(_ data: Data) throws -> FITSImage {
        let header = try FITSHeader.parse(data)
        guard header.bool("SIMPLE") == true else { throw FITSError.notFITS }
        let naxis = header.int("NAXIS") ?? 0
        guard naxis != 0 else { throw FITSError.unsupported("nessuna immagine nell'HDU primaria (file compresso?)") }
        guard naxis == 2 else { throw FITSError.unsupported("NAXIS = \(naxis)") }
        guard let bitpix = header.int("BITPIX"), [8, 16, 32, -32].contains(bitpix) else {
            throw FITSError.unsupported("BITPIX = \(header.int("BITPIX").map(String.init) ?? "?")")
        }
        guard let width = header.int("NAXIS1"), let height = header.int("NAXIS2"), width > 0, height > 0 else {
            throw FITSError.unsupported("dimensioni non valide")
        }
        let bzero = header.double("BZERO") ?? 0
        let bscale = header.double("BSCALE") ?? 1
        let count = width * height
        let start = header.byteLength
        guard data.count >= start + count * abs(bitpix) / 8 else { throw FITSError.truncatedData }

        var pixels = [Float](repeating: 0, count: count)
        let scale = Float(bscale)
        let zero = Float(bzero)
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let base = raw.baseAddress!.advanced(by: start)
            pixels.withUnsafeMutableBufferPointer { out in
                switch bitpix {
                case 8:
                    for i in 0..<count {
                        out[i] = Float(base.load(fromByteOffset: i, as: UInt8.self)) * scale + zero
                    }
                case 16:
                    for i in 0..<count {
                        let bits = UInt16(bigEndian: base.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self))
                        out[i] = Float(Int16(bitPattern: bits)) * scale + zero
                    }
                case 32:
                    for i in 0..<count {
                        let bits = UInt32(bigEndian: base.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self))
                        out[i] = Float(Double(Int32(bitPattern: bits)) * bscale + bzero)
                    }
                default:
                    for i in 0..<count {
                        let bits = UInt32(bigEndian: base.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self))
                        out[i] = Float(bitPattern: bits) * scale + zero
                    }
                }
            }
        }
        let maxRaw: Double? = switch bitpix {
        case 8: 255
        case 16: 32767
        case 32: 2_147_483_647
        default: nil
        }
        return FITSImage(header: header, width: width, height: height, bitpix: bitpix, pixels: pixels,
                         maxRepresentable: maxRaw.map { Float($0 * bscale + bzero) })
    }
}
