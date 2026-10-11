import Foundation

public enum ImageType: String, Sendable, Codable, CaseIterable {
    case light, dark, flat, bias, darkFlat, unknown

    public init(fitsValue: String?) {
        let v = (fitsValue ?? "").lowercased().replacingOccurrences(of: " ", with: "")
        if v.contains("light") { self = .light }
        else if v.contains("darkflat") || v.contains("flatdark") { self = .darkFlat }
        else if v.contains("dark") { self = .dark }
        else if v.contains("flat") { self = .flat }
        else if v.contains("bias") || v.contains("offset") { self = .bias }
        else { self = .unknown }
    }

    public var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .flat: "Flat"
        case .bias: "Bias"
        case .darkFlat: "Dark flat"
        case .unknown: "Sconosciuto"
        }
    }
}

public struct FrameMeta: Sendable, Codable, Equatable {
    public var width: Int
    public var height: Int
    public var exposure: Double?
    public var gain: Int?
    public var offset: Int?
    public var sensorTemp: Double?
    public var setTemp: Double?
    public var dateObs: Date?
    public var object: String?
    public var imageType: ImageType
    public var bayerPattern: String?
    public var pixelSizeMicrons: Double?
    public var focalLengthMM: Double?
    public var binning: Int
    public var filter: String?
    public var airmass: Double?
    public var instrument: String?

    public init(header: FITSHeader) {
        width = header.int("NAXIS1") ?? 0
        height = header.int("NAXIS2") ?? 0
        exposure = header.double("EXPTIME") ?? header.double("EXPOSURE")
        gain = header.int("GAIN") ?? header.double("GAIN").map { Int($0.rounded()) }
        offset = header.int("OFFSET")
        sensorTemp = header.double("CCD-TEMP")
        setTemp = header.double("SET-TEMP")
        dateObs = header.string("DATE-OBS").flatMap(FrameMeta.parseDate)
        object = header.string("OBJECT").flatMap { $0.isEmpty ? nil : $0 }
        imageType = ImageType(fitsValue: header.string("IMAGETYP") ?? header.string("FRAME"))
        let pattern = header.string("BAYERPAT")?.uppercased()
        bayerPattern = pattern.flatMap { ["RGGB", "BGGR", "GRBG", "GBRG"].contains($0) ? $0 : nil }
        pixelSizeMicrons = header.double("XPIXSZ")
        focalLengthMM = header.double("FOCALLEN")
        binning = header.int("XBINNING") ?? 1
        filter = header.string("FILTER").flatMap { $0.isEmpty ? nil : $0 }
        airmass = header.double("AIRMASS")
        instrument = header.string("INSTRUME")
    }

    /// Secondi d'arco per pixel del sensore. XPIXSZ include già il binning (convenzione SBIG/ASIAIR/N.I.N.A.).
    public var pixelScale: Double? {
        guard let p = pixelSizeMicrons, let f = focalLengthMM, p > 0, f > 0 else { return nil }
        return 206.264806 * p / f
    }

    /// ISO 8601 senza fuso (UTC), con frazioni di secondo di lunghezza variabile.
    static func parseDate(_ text: String) -> Date? {
        let parts = text.split(separator: ".", maxSplits: 1)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let first = parts.first, let base = formatter.date(from: String(first)) else { return nil }
        guard parts.count == 2, let fraction = Double("0." + parts[1].filter(\.isNumber)) else { return base }
        return base.addingTimeInterval(fraction)
    }
}
