import FitsCullCore
import SwiftUI

/// Grafici della serie (stile PixInsight): una colonna per light dello stesso filtro del frame selezionato,
/// in ordine di ripresa o ordinate per valore. Frame corrente in azzurro, scartati in rosso;
/// clic su una colonna = apre quel frame.
struct FrameMetricsView: View {
    @Environment(SessionModel.self) private var model
    let group: FrameGroup
    let records: [FrameRecord]

    var body: some View {
        let frames = records.map { (id: $0.id, analysis: $0.analysis, rejected: $0.rejected) }
        let current = model.selectedRecord
        VStack(spacing: 6) {
            chart("Stars", MetricSeries(.stars, frames: frames), digits: 0, current: current)
            chart("Background (ADU)", MetricSeries(.background, frames: frames), digits: 0, current: current)
            let fwhm = MetricSeries(.fwhm, frames: frames)
            chart(fwhm.inArcsec ? "FWHM (″)" : "FWHM (px)", fwhm, digits: 2, current: current)
            chart("Eccentricity", MetricSeries(.eccentricity, frames: frames), digits: 2, current: current)
        }
    }

    private func chart(_ title: String, _ series: MetricSeries, digits: Int, current: FrameRecord?) -> some View {
        MetricBarChart(title: title, series: series, digits: digits,
                       current: current?.id, currentIndex: current?.index) { model.selection = $0 }
    }
}

private enum ChartColor {
    static let background = Color(red: 0.118, green: 0.122, blue: 0.169)
    static let grid = Color(red: 0.173, green: 0.180, blue: 0.243)
    static let label = Color(red: 0.604, green: 0.612, blue: 0.671)
    static let bar = Color(red: 0.184, green: 0.427, blue: 0.710)
    static let current = Color(red: 0.561, green: 0.827, blue: 1.0)
    static let rejected = Color(red: 0.898, green: 0.282, blue: 0.302)
    static let median = Color(red: 0.608, green: 0.890, blue: 0.627)
}

struct MetricBarChart: View {
    let title: String
    let series: MetricSeries
    let digits: Int
    let current: URL?
    let currentIndex: Int?
    let onPick: (URL) -> Void

    /// Ordine scelto con l'icona del grafico; resta mentre si passa da un frame all'altro.
    @State private var order: BarOrder = .capture

    private let gutter: CGFloat = 40
    private let inset: CGFloat = 4

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).foregroundStyle(.white)
                Spacer()
                if let current, let currentIndex, let value = series.value(for: current) {
                    Text(verbatim: "#\(currentIndex): \(Format.number(value, digits: digits))")
                        .foregroundStyle(ChartColor.current)
                }
                Button { order = order.next } label: {
                    Image(systemName: order.symbol)
                        .foregroundStyle(order == .capture ? ChartColor.label : ChartColor.current)
                        .frame(width: 16, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(order.help)
            }
            .font(.caption2.bold().monospacedDigit())
            .padding(.horizontal, 4)
            GeometryReader { geo in
                let shown = series.sorted(order)
                Canvas { context, size in draw(shown, in: &context, size: size) }
                    .contentShape(Rectangle())
                    .onTapGesture { location in pick(shown, at: location.x, width: geo.size.width) }
            }
            .frame(height: 92)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(ChartColor.background, in: .rect(cornerRadius: 4))
    }

    private func plotRect(_ size: CGSize) -> CGRect {
        CGRect(x: gutter, y: inset, width: max(size.width - gutter - inset, 1), height: max(size.height - 2 * inset, 1))
    }

    private func pick(_ series: MetricSeries, at x: CGFloat, width: CGFloat) {
        guard !series.bars.isEmpty else { return }
        let plot = plotRect(CGSize(width: width, height: 1))
        let i = Int((x - plot.minX) / plot.width * CGFloat(series.bars.count))
        onPick(series.bars[min(max(i, 0), series.bars.count - 1)].id)
    }

    private func draw(_ series: MetricSeries, in context: inout GraphicsContext, size: CGSize) {
        let plot = plotRect(size)
        guard let domain = series.axisDomain else {
            context.draw(Text("Waiting for analysis…").font(.caption2).foregroundStyle(ChartColor.label),
                         at: CGPoint(x: plot.midX, y: plot.midY))
            return
        }
        let span = domain.upperBound - domain.lowerBound
        func y(_ v: Double) -> CGFloat { plot.maxY - plot.height * CGFloat((v - domain.lowerBound) / span) }

        for k in 0...4 {
            let v = domain.lowerBound + span * Double(k) / 4
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y(v)))
            line.addLine(to: CGPoint(x: plot.maxX, y: y(v)))
            context.stroke(line, with: .color(ChartColor.grid), lineWidth: 1)
            context.draw(Text(Format.number(v, digits: digits)).font(.system(size: 8.5).monospacedDigit())
                            .foregroundStyle(ChartColor.label),
                         at: CGPoint(x: plot.minX - 4, y: y(v)), anchor: .trailing)
        }

        // Su sessioni lunghe le colonne sono più strette di un punto: corrente e scartati restano comunque visibili.
        let step = plot.width / CGFloat(series.bars.count)
        let gap: CGFloat = step > 3 ? 0.5 : 0
        func column(_ i: Int, _ value: Double, minWidth: CGFloat) -> CGRect {
            let width = max(step - gap, minWidth)
            let x = plot.minX + step * CGFloat(i) + (step - width) / 2
            let top = y(value)
            return CGRect(x: x, y: top, width: width, height: max(plot.maxY - top, 1))
        }
        var currentColumn: CGRect?
        for (i, bar) in series.bars.enumerated() {
            guard let value = bar.value else { continue }
            if bar.id == current {
                currentColumn = column(i, value, minWidth: 2)
            } else if bar.rejected {
                context.fill(Path(column(i, value, minWidth: 1.5)), with: .color(ChartColor.rejected))
            } else {
                context.fill(Path(column(i, value, minWidth: 0.5)), with: .color(ChartColor.bar))
            }
        }
        if let currentColumn { context.fill(Path(currentColumn), with: .color(ChartColor.current)) }

        if let median = series.median {
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y(median)))
            line.addLine(to: CGPoint(x: plot.maxX, y: y(median)))
            context.stroke(line, with: .color(ChartColor.median), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            context.draw(Text(Format.number(median, digits: digits)).font(.system(size: 9, weight: .bold).monospacedDigit())
                            .foregroundStyle(ChartColor.median),
                         at: CGPoint(x: plot.minX + 4, y: y(median) - 2), anchor: .bottomLeading)
        }

        var axis = Path()
        axis.move(to: CGPoint(x: plot.minX, y: plot.minY))
        axis.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        context.stroke(axis, with: .color(ChartColor.label.opacity(0.6)), lineWidth: 1)
    }
}

private extension BarOrder {
    var symbol: String {
        switch self {
        case .capture: "chart.bar.xaxis"
        case .ascending: "chart.bar.xaxis.ascending"
        case .descending: "chart.bar.xaxis.descending"
        }
    }

    var help: String {
        switch self {
        case .capture: "Capture order — click to sort ascending"
        case .ascending: "Ascending — click to sort descending"
        case .descending: "Descending — click for capture order"
        }
    }
}
