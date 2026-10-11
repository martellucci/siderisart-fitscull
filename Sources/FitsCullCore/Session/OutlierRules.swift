public struct SessionSummary: Sendable, Equatable {
    public var medianBackground: Double
    public var medianStars: Double
    public var medianFWHM: Double?
    /// 1,4826 × MAD delle FWHM (pixel).
    public var sigmaFWHM: Double?
}

public struct OutlierFlags: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let background = OutlierFlags(rawValue: 1 << 0)
    public static let stars = OutlierFlags(rawValue: 1 << 1)
    public static let fwhm = OutlierFlags(rawValue: 1 << 2)
    public static let eccentricity = OutlierFlags(rawValue: 1 << 3)
}

/// Segnalazioni rispetto alla mediana della sessione (spec §5.1). Non scartano nulla da sole.
public enum OutlierRules {
    public static let backgroundRatio = 1.30
    public static let starsRatio = 0.50
    public static let fwhmSigmas = 2.0
    /// Fissa, non relativa alla sessione: un file mosso lo è comunque. FitsCull legge l'eccentricità
    /// ~6–12% più alta di PixInsight, quindi 0,75 corrisponde a ~0,67–0,70 in PixInsight.
    public static let maxEccentricity = 0.75

    public static func summary(_ analyses: [FrameAnalysis]) -> SessionSummary? {
        guard !analyses.isEmpty else { return nil }
        let measured = analyses.compactMap(\.stars)
        let fwhms = measured.compactMap(\.fwhm)
        let medianFWHM = fwhms.isEmpty ? nil : RobustStats.exactMedian(fwhms)
        let sigmaFWHM = medianFWHM.map { m in 1.4826 * RobustStats.exactMedian(fwhms.map { abs($0 - m) }) }
        return SessionSummary(medianBackground: RobustStats.exactMedian(analyses.map(\.background)),
                              medianStars: measured.isEmpty ? 0 : RobustStats.exactMedian(measured.map { Double($0.count) }),
                              medianFWHM: medianFWHM, sigmaFWHM: sigmaFWHM)
    }

    public static func flags(for a: FrameAnalysis, in s: SessionSummary) -> OutlierFlags {
        var flags: OutlierFlags = []
        if s.medianBackground > 0, a.background > s.medianBackground * backgroundRatio { flags.insert(.background) }
        guard let stars = a.stars else { return flags }
        if s.medianStars > 0, Double(stars.count) < s.medianStars * starsRatio { flags.insert(.stars) }
        if let m = s.medianFWHM, let sd = s.sigmaFWHM, let v = stars.fwhm,
           v > m + fwhmSigmas * max(sd, 0.05 * m) { flags.insert(.fwhm) }
        if let e = stars.eccentricity, e > maxEccentricity { flags.insert(.eccentricity) }
        return flags
    }
}

/// Soglie impostate dall'utente nella vista Sessione (nil = nessuna soglia).
public struct Thresholds: Sendable, Equatable, Codable {
    /// In ″ quando la scala è nota, altrimenti in pixel.
    public var maxFWHM: Double?
    public var minStars: Int?
    public var maxBackground: Double?
    public var maxEccentricity: Double?

    public init(maxFWHM: Double? = nil, minStars: Int? = nil, maxBackground: Double? = nil, maxEccentricity: Double? = nil) {
        self.maxFWHM = maxFWHM
        self.minStars = minStars
        self.maxBackground = maxBackground
        self.maxEccentricity = maxEccentricity
    }

    public func violates(_ a: FrameAnalysis) -> Bool {
        if let t = maxBackground, a.background > t { return true }
        guard let stars = a.stars else { return false }
        if let t = maxFWHM, let v = stars.fwhmArcsec ?? stars.fwhm, v > t { return true }
        if let t = minStars, stars.count < t { return true }
        if let t = maxEccentricity, let e = stars.eccentricity, e > t { return true }
        return false
    }
}
