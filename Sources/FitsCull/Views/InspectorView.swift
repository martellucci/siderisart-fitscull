import FitsCullCore
import SwiftUI

struct InspectorView: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        ScrollView {
            if let record = model.selectedRecord {
                VStack(alignment: .leading, spacing: 14) {
                    section("FILE") {
                        Text(record.id.lastPathComponent).font(.callout.bold()).textSelection(.enabled)
                        if let meta = record.meta {
                            Text(Format.metaLine(meta)).font(.caption)
                            Text(Format.opticsLine(meta)).font(.caption)
                        }
                    }
                    if let analysis = record.analysis {
                        section("STATISTICHE") { StatsGrid(analysis: analysis) }
                        if let stars = analysis.stars {
                            section("STELLE") { StarsGrid(stars: stars) }
                        }
                        if !record.flags.isEmpty {
                            Label(Format.flags(record.flags), systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if let preview = model.previews[record.id] {
                        section("ISTOGRAMMA (visualizzato)") {
                            HistogramView(histogram: preview.histogram).frame(height: 80)
                        }
                    }
                    if let header = record.header {
                        DisclosureGroup("Header FITS (\(header.cards.count))") {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(Array(header.cards.enumerated()), id: \.offset) { _, card in
                                    Text(card.raw.trimmingCharacters(in: .whitespaces))
                                        .font(.system(.caption2, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Nessun file selezionato").foregroundStyle(.secondary).padding()
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            content()
        }
    }
}

struct StatsGrid: View {
    let analysis: FrameAnalysis

    var body: some View {
        let channels = analysis.channels
        Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 3) {
            GridRow {
                Text("")
                ForEach(analysis.channelNames, id: \.self) { Text($0).bold() }
            }
            row("Mediana", channels.map { Format.number($0.median, digits: 0) })
            row("Media", channels.map { Format.number($0.mean, digits: 0) })
            row("σ", channels.map { Format.number($0.stdDev, digits: 1) })
            row("Rumore", channels.map { Format.number($0.noise, digits: 1) })
            row("Min", channels.map { Format.number($0.min, digits: 0) })
            row("Max", channels.map { Format.number($0.max, digits: 0) })
            row("Saturi", channels.map { Format.number($0.saturatedFraction.map { $0 * 100 }, digits: 3, suffix: "%") })
        }
        .font(.caption.monospacedDigit())
    }

    private func row(_ label: String, _ values: [String]) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.leading)
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in Text(value) }
        }
    }
}

struct StarsGrid: View {
    let stars: StarMetrics

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
            GridRow { Text("Stelle").foregroundStyle(.secondary); Text("\(stars.count)") }
            GridRow { Text("FWHM").foregroundStyle(.secondary); Text(fwhmText) }
            GridRow { Text("HFR").foregroundStyle(.secondary); Text(Format.number(stars.hfr, digits: 2, suffix: " px")) }
            GridRow { Text("Eccentricità").foregroundStyle(.secondary); Text(Format.number(stars.eccentricity, digits: 2)) }
        }
        .font(.caption.monospacedDigit())
    }

    private var fwhmText: String {
        let px = Format.number(stars.fwhm, digits: 2, suffix: " px")
        guard let arcsec = stars.fwhmArcsec else { return px }
        return Format.number(arcsec, digits: 2, suffix: "″") + " (" + px + ")"
    }
}
