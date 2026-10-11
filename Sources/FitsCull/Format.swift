import FitsCullCore
import Foundation

enum Format {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }

    static func number(_ value: Double?, digits: Int, suffix: String = "") -> String {
        guard let value, value.isFinite else { return "–" }
        return String(format: "%.\(digits)f", value) + suffix
    }

    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    static func metaLine(_ m: FrameMeta) -> String {
        let parts: [String?] = [m.imageType.label, m.exposure.map { number($0, digits: 0, suffix: " s") },
                                m.gain.map { "gain \($0)" }, m.sensorTemp.map { number($0, digits: 1, suffix: " °C") },
                                m.filter]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    static func opticsLine(_ m: FrameMeta) -> String {
        let parts: [String?] = [m.pixelScale.map { number($0, digits: 2, suffix: "″/px") }, m.bayerPattern,
                                m.focalLengthMM.map { number($0, digits: 0, suffix: " mm") }, m.object]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    static func flags(_ f: OutlierFlags) -> String {
        var parts: [String] = []
        if f.contains(.background) { parts.append("fondo alto") }
        if f.contains(.stars) { parts.append("poche stelle") }
        if f.contains(.fwhm) { parts.append("FWHM alta") }
        if f.contains(.eccentricity) { parts.append("stelle allungate") }
        return parts.joined(separator: ", ")
    }
}
