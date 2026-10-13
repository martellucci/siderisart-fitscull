import Foundation

public enum FITSError: Error, Equatable, Sendable, CustomStringConvertible {
    case notFITS
    case truncatedHeader
    case truncatedData
    case unsupported(String)

    public var description: String {
        switch self {
        case .notFITS: "not a FITS file"
        case .truncatedHeader: "incomplete FITS header"
        case .truncatedData: "truncated file (interrupted copy?)"
        case .unsupported(let reason): "unsupported: \(reason)"
        }
    }
}

public enum FITSValue: Sendable, Equatable, Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

public struct FITSCard: Sendable, Equatable, Codable {
    public let key: String
    public let value: FITSValue?
    public let comment: String
    public let raw: String

    public init(key: String, value: FITSValue?, comment: String, raw: String) {
        self.key = key
        self.value = value
        self.comment = comment
        self.raw = raw
    }
}

public struct FITSHeader: Sendable, Equatable {
    public static let blockSize = 2880
    public static let cardSize = 80

    public let cards: [FITSCard]
    /// Lunghezza dell'header in byte, compreso il riempimento a multipli di 2880.
    public let byteLength: Int

    public init(cards: [FITSCard], byteLength: Int) {
        self.cards = cards
        self.byteLength = byteLength
    }

    public subscript(key: String) -> FITSValue? {
        cards.first { $0.key == key && $0.value != nil }?.value
    }

    public func string(_ key: String) -> String? {
        switch self[key] {
        case .string(let s): s
        case .int(let i): String(i)
        case .double(let d): String(d)
        case .bool(let b): b ? "T" : "F"
        case nil: nil
        }
    }

    public func double(_ key: String) -> Double? {
        switch self[key] {
        case .double(let d): d
        case .int(let i): Double(i)
        case .string(let s): Double(s)
        default: nil
        }
    }

    public func int(_ key: String) -> Int? {
        switch self[key] {
        case .int(let i): i
        case .double(let d) where d.rounded() == d && abs(d) < 1e15: Int(d)
        case .string(let s): Int(s)
        default: nil
        }
    }

    public func bool(_ key: String) -> Bool? {
        if case .bool(let b) = self[key] { return b }
        return nil
    }

    /// Legge card da 80 byte fino a END. Il primo card deve essere SIMPLE.
    public static func parse(_ data: Data) throws -> FITSHeader {
        var cards: [FITSCard] = []
        var offset = 0
        while offset + cardSize <= data.count {
            let start = data.startIndex + offset
            let card = parseCard(String(decoding: data[start ..< start + cardSize], as: UTF8.self))
            if cards.isEmpty && card.key != "SIMPLE" { throw FITSError.notFITS }
            offset += cardSize
            if card.key == "END" {
                let blocks = (offset + blockSize - 1) / blockSize
                return FITSHeader(cards: cards, byteLength: blocks * blockSize)
            }
            cards.append(card)
        }
        if cards.isEmpty { throw FITSError.notFITS }
        throw FITSError.truncatedHeader
    }

    static func parseCard(_ raw: String) -> FITSCard {
        let bytes = Array(raw.utf8)
        let key = String(decoding: bytes.prefix(8), as: UTF8.self).trimmingCharacters(in: .whitespaces)
        guard bytes.count >= 10, bytes[8] == UInt8(ascii: "="), bytes[9] == UInt8(ascii: " ") else {
            return FITSCard(key: key, value: nil, comment: "", raw: raw)
        }
        let field = Array(bytes[10...])
        var i = 0
        while i < field.count, field[i] == UInt8(ascii: " ") { i += 1 }

        if i < field.count, field[i] == UInt8(ascii: "'") {
            var chars: [UInt8] = []
            i += 1
            while i < field.count {
                if field[i] == UInt8(ascii: "'") {
                    if i + 1 < field.count, field[i + 1] == UInt8(ascii: "'") {
                        chars.append(field[i])
                        i += 2
                        continue
                    }
                    i += 1
                    break
                }
                chars.append(field[i])
                i += 1
            }
            let value = String(decoding: chars, as: UTF8.self).trimmingCharacters(in: .whitespaces)
            return FITSCard(key: key, value: .string(value), comment: comment(in: field, from: i), raw: raw)
        }

        let rest = String(decoding: field[i...], as: UTF8.self)
        let parts = rest.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let token = parts.first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let comment = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        return FITSCard(key: key, value: parseValue(token), comment: comment, raw: raw)
    }

    private static func comment(in field: [UInt8], from index: Int) -> String {
        guard index < field.count else { return "" }
        let rest = String(decoding: field[index...], as: UTF8.self)
        guard let slash = rest.firstIndex(of: "/") else { return "" }
        return rest[rest.index(after: slash)...].trimmingCharacters(in: .whitespaces)
    }

    static func parseValue(_ token: String) -> FITSValue? {
        if token == "T" { return .bool(true) }
        if token == "F" { return .bool(false) }
        if let i = Int(token) { return .int(i) }
        if let d = Double(token.replacingOccurrences(of: "D", with: "E")) { return .double(d) }
        return nil
    }
}
