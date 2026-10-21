import Foundation

/// Metriche mostrate nei grafici della sessione.
public enum FrameMetric: CaseIterable, Sendable {
    case stars, background, fwhm, eccentricity
}

/// Ordine delle colonne di un grafico; l'icona sul grafico passa al successivo.
public enum BarOrder: CaseIterable, Sendable {
    case capture, ascending, descending

    public var next: BarOrder {
        switch self {
        case .capture: .ascending
        case .ascending: .descending
        case .descending: .capture
        }
    }
}

/// Valori di una metrica per una serie di frame (un gruppo, in ordine di ripresa): una colonna per frame.
public struct MetricSeries: Sendable, Equatable {
    public struct Bar: Sendable, Equatable {
        public let id: URL
        /// nil = non (ancora) misurato: la colonna resta vuota e i grafici restano allineati.
        public let value: Double?
        public let rejected: Bool
    }

    public let metric: FrameMetric
    public private(set) var bars: [Bar]
    public let median: Double?
    /// Solo FWHM: in ″ se tutti i frame misurati hanno la scala, altrimenti in pixel (mai unità miste).
    public let inArcsec: Bool

    public init(_ metric: FrameMetric, frames: [(id: URL, analysis: FrameAnalysis?, rejected: Bool)]) {
        let measured = frames.compactMap { $0.analysis?.stars?.fwhm == nil ? nil : $0.analysis?.stars }
        let arcsec = metric == .fwhm && !measured.isEmpty && measured.allSatisfy { $0.fwhmArcsec != nil }
        let bars = frames.map { frame in
            Bar(id: frame.id, value: frame.analysis.flatMap { Self.value(metric, of: $0, arcsec: arcsec) },
                rejected: frame.rejected)
        }
        let values = bars.compactMap(\.value)
        self.metric = metric
        self.bars = bars
        self.median = values.isEmpty ? nil : RobustStats.exactMedian(values)
        self.inArcsec = arcsec
    }

    /// Stessi valori e stessa mediana, colonne riordinate. A parità di valore resta l'ordine di ripresa;
    /// i frame senza valore vanno in fondo.
    public func sorted(_ order: BarOrder) -> MetricSeries {
        guard order != .capture else { return self }
        var copy = self
        let positions = Dictionary(uniqueKeysWithValues: bars.enumerated().map { ($1.id, $0) })
        copy.bars = RowOrder.sorted(bars, ascending: order == .ascending, value: \.value) { positions[$0.id] ?? 0 }
        return copy
    }

    public func value(for id: URL) -> Double? {
        bars.first { $0.id == id }?.value
    }

    /// Asse verticale: dal minimo al massimo con un 5% di margine, così anche il frame migliore ha una colonna visibile.
    public var axisDomain: ClosedRange<Double>? {
        let values = bars.compactMap(\.value)
        guard let lo = values.min(), let hi = values.max() else { return nil }
        let pad = hi > lo ? (hi - lo) * 0.05 : Swift.max(abs(lo) * 0.05, 1)
        return (lo - pad)...(hi + pad)
    }

    private static func value(_ metric: FrameMetric, of a: FrameAnalysis, arcsec: Bool) -> Double? {
        let v: Double?
        switch metric {
        case .stars: v = a.stars.map { Double($0.count) }
        case .background: v = a.background
        case .fwhm: v = arcsec ? a.stars?.fwhmArcsec : a.stars?.fwhm
        case .eccentricity: v = a.stars?.eccentricity
        }
        return v.flatMap { $0.isFinite ? $0 : nil }
    }
}
