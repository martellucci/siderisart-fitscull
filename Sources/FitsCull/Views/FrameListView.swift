import FitsCullCore
import SwiftUI

struct FrameListView: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Table(model.visibleRecords, selection: $model.selection) {
            TableColumn("#") { r in
                Text(verbatim: "\(r.index)").monospacedDigit().strikethrough(r.rejected)
            }
            .width(36)
            TableColumn("Time") { r in Text(r.meta?.dateObs.map(Format.time) ?? "–").monospacedDigit() }
                .width(44)
            TableColumn("Exp") { r in Text(Format.number(r.meta?.exposure, digits: 0, suffix: "s")).monospacedDigit() }
                .width(44)
            TableColumn("Bkg") { r in
                FlaggedCell(text: Format.number(r.analysis?.background, digits: 0), flagged: r.flags.contains(.background))
            }
            .width(52)
            TableColumn("FWHM″") { r in
                FlaggedCell(text: Format.number(r.analysis?.stars?.fwhmArcsec ?? r.analysis?.stars?.fwhm, digits: 2),
                            flagged: r.flags.contains(.fwhm))
            }
            .width(52)
            TableColumn("★") { r in
                FlaggedCell(text: r.analysis?.stars.map { "\($0.count)" } ?? "–", flagged: r.flags.contains(.stars))
            }
            .width(44)
            TableColumn("Ecc") { r in
                FlaggedCell(text: Format.number(r.analysis?.stars?.eccentricity, digits: 2), flagged: r.flags.contains(.eccentricity))
            }
            .width(40)
            TableColumn("Status") { r in StatusBadge(record: r) }
                .width(64)
        }
    }
}

struct FlaggedCell: View {
    let text: String
    let flagged: Bool

    var body: some View {
        Text(text)
            .monospacedDigit()
            .foregroundStyle(flagged ? Color.orange : Color.primary)
            .fontWeight(flagged ? .semibold : .regular)
    }
}

struct StatusBadge: View {
    let record: FrameRecord

    var body: some View {
        if record.rejected {
            Text("✗ reject").foregroundStyle(.red)
        } else {
            switch record.status {
            case .pending:
                Text("…").foregroundStyle(.secondary)
            case .analyzing:
                ProgressView().controlSize(.mini)
            case .failed(let message):
                Text("error").foregroundStyle(.red).help(message)
            case .done:
                if record.flags.isEmpty {
                    Text("✓").foregroundStyle(.green)
                } else {
                    Text("⚠︎").foregroundStyle(.orange).help(Format.flags(record.flags))
                }
            }
        }
    }
}
