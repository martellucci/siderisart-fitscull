import Charts
import FitsCullCore
import SwiftUI

struct ChartPoint: Identifiable {
    let id: URL
    let x: Date
    let y: Double
    let rejected: Bool
    let outOfThreshold: Bool
}

struct SessionChartsView: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    MetricChart(title: "FWHM (″)", points: points { $0.stars?.fwhmArcsec ?? $0.stars?.fwhm },
                                threshold: model.thresholds.maxFWHM, onPick: open)
                    MetricChart(title: "Stelle", points: points { $0.stars.map { Double($0.count) } },
                                threshold: model.thresholds.minStars.map(Double.init), onPick: open)
                    MetricChart(title: "Fondo (ADU)", points: points { $0.background },
                                threshold: model.thresholds.maxBackground, onPick: open)
                    MetricChart(title: "Eccentricità", points: points { $0.stars?.eccentricity },
                                threshold: model.thresholds.maxEccentricity, onPick: open)
                }
                .padding()
            }
            Divider()
            ThresholdForm().frame(width: 250)
        }
    }

    private func points(_ value: (FrameAnalysis) -> Double?) -> [ChartPoint] {
        model.visibleRecords.compactMap { r in
            guard let a = r.analysis, let y = value(a), y.isFinite else { return nil }
            return ChartPoint(id: r.id, x: r.meta?.dateObs ?? Date(timeIntervalSinceReferenceDate: Double(r.index) * 60),
                              y: y, rejected: r.rejected, outOfThreshold: model.thresholds.violates(a))
        }
    }

    private func open(_ id: URL) {
        model.selection = id
        model.viewMode = .review
    }
}

struct MetricChart: View {
    let title: String
    let points: [ChartPoint]
    let threshold: Double?
    let onPick: (URL) -> Void
    @State private var selectedX: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Chart {
                ForEach(points) { p in
                    PointMark(x: .value("Ora", p.x), y: .value(title, p.y))
                        .foregroundStyle(p.rejected ? Color.red : (p.outOfThreshold ? Color.orange : Color.accentColor))
                        .symbolSize(p.rejected ? 50 : 30)
                }
                if let threshold {
                    RuleMark(y: .value("Soglia", threshold))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartXAxis { AxisMarks(values: .automatic) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.hour().minute()) } }
            .chartXSelection(value: $selectedX)
            .onChange(of: selectedX) { _, x in
                guard let x, let nearest = points.min(by: { abs($0.x.timeIntervalSince(x)) < abs($1.x.timeIntervalSince(x)) })
                else { return }
                onPick(nearest.id)
            }
            .frame(height: 140)
        }
    }
}

struct ThresholdForm: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Soglie (vuoto = nessuna)") {
                TextField("FWHM max (″)", value: $model.thresholds.maxFWHM, format: .number)
                TextField("Stelle min", value: $model.thresholds.minStars, format: .number)
                TextField("Fondo max (ADU)", value: $model.thresholds.maxBackground, format: .number)
                TextField("Eccentricità max", value: $model.thresholds.maxEccentricity, format: .number)
            }
            Section {
                Button("Segna fuori soglia (\(model.outOfThresholdCount))") { model.markOutOfThreshold() }
                    .disabled(model.outOfThresholdCount == 0)
                Button("Azzera soglie") { model.thresholds = Thresholds() }
            }
        }
        .formStyle(.grouped)
    }
}
