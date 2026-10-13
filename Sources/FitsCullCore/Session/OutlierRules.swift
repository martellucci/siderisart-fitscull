import Foundation


public struct SessionSummary: Sendable, Equatable {
    public var medianBackground: Double
    public var medianStars: Double
    public var medianFWHM: Double?
}

public struct OutlierFlags: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let background = OutlierFlags(rawValue: 1 << 0)
    public static let stars = OutlierFlags(rawValue: 1 << 1)
    public static let fwhm = OutlierFlags(rawValue: 1 << 2)
    public static let eccentricity = OutlierFlags(rawValue: 1 << 3)
}

/// Soglie delle segnalazioni, modificabili dall'utente in Settings. I predefiniti sono quelli tarati
/// sul confronto con PixInsight (v1.0.0).
public struct AlertSettings: Sendable, Equatable, Codable {
    /// Fondo segnalato oltre la mediana di sessione + questa percentuale…
    public var backgroundEnabled = true
    public var backgroundExcessPercent = 30.0
    /// …e solo se supera anche questo valore assoluto (ADU): evita avvisi sui fondi bassi.
    public var minBackgroundADU = 3000.0
    /// Stelle segnalate sotto questa percentuale della mediana di sessione.
    public var starsEnabled = true
    public var starsMinPercent = 50.0
    /// FWHM segnalata oltre la mediana di sessione + questa percentuale: sotto, è seeing normale.
    public var fwhmEnabled = true
    public var fwhmExcessPercent = 25.0
    /// Fissa, non relativa alla sessione: un file mosso lo è comunque. FitsCull legge l'eccentricità
    /// ~6–12% più alta di PixInsight, quindi 0,75 corrisponde a ~0,67–0,70 in PixInsight.
    public var eccentricityEnabled = true
    public var maxEccentricity = 0.75

    public init() {}

    public static let defaults = AlertSettings()

    /// Riporta i valori in intervalli sensati (anche quelli letti da preferenze vecchie o modificate a mano).
    public func clamped() -> AlertSettings {
        var c = self
        c.backgroundExcessPercent = backgroundExcessPercent.clamped(to: 0...500)
        c.minBackgroundADU = minBackgroundADU.clamped(to: 0...65535)
        c.starsMinPercent = starsMinPercent.clamped(to: 0...100)
        c.fwhmExcessPercent = fwhmExcessPercent.clamped(to: 0...500)
        c.maxEccentricity = maxEccentricity.clamped(to: 0...1)
        return c
    }

    public static let defaultsKey = "alertSettings"

    /// Impostazioni salvate; i predefiniti se mancano o non sono leggibili.
    public static func load(from defaults: UserDefaults = .standard) -> AlertSettings {
        guard let data = defaults.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(AlertSettings.self, from: data) else { return .defaults }
        return settings.clamped()
    }

    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.defaultsKey) }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}

/// Segnalazioni rispetto alla mediana della sessione (spec §5.1). Non scartano nulla da sole.
public enum OutlierRules {
    public static func summary(_ analyses: [FrameAnalysis]) -> SessionSummary? {
        guard !analyses.isEmpty else { return nil }
        let measured = analyses.compactMap(\.stars)
        let fwhms = measured.compactMap(\.fwhm)
        let medianFWHM = fwhms.isEmpty ? nil : RobustStats.exactMedian(fwhms)
        return SessionSummary(medianBackground: RobustStats.exactMedian(analyses.map(\.background)),
                              medianStars: measured.isEmpty ? 0 : RobustStats.exactMedian(measured.map { Double($0.count) }),
                              medianFWHM: medianFWHM)
    }

    public static func flags(for a: FrameAnalysis, in s: SessionSummary, settings: AlertSettings = .defaults) -> OutlierFlags {
        var flags: OutlierFlags = []
        if settings.backgroundEnabled, s.medianBackground > 0,
           a.background > s.medianBackground * (1 + settings.backgroundExcessPercent / 100),
           a.background > settings.minBackgroundADU { flags.insert(.background) }
        guard let stars = a.stars else { return flags }
        if settings.starsEnabled, s.medianStars > 0,
           Double(stars.count) < s.medianStars * settings.starsMinPercent / 100 { flags.insert(.stars) }
        if settings.fwhmEnabled, let m = s.medianFWHM, let v = stars.fwhm,
           v > m * (1 + settings.fwhmExcessPercent / 100) { flags.insert(.fwhm) }
        if settings.eccentricityEnabled, let e = stars.eccentricity, e > settings.maxEccentricity { flags.insert(.eccentricity) }
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
