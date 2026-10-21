import FitsCullCore
import SwiftUI

struct FrameListView: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollViewReader { proxy in
            Table(model.visibleRecords, selection: $model.selection, sortOrder: $model.sortOrder) {
                TableColumn("#", sortUsing: FrameSort(column: .index)) { r in
                    Text(verbatim: "\(r.index)").monospacedDigit().strikethrough(r.rejected)
                }
                .width(36)
                TableColumn("Time", sortUsing: FrameSort(column: .time)) { r in Text(r.meta?.dateObs.map(Format.time) ?? "–").monospacedDigit() }
                    .width(44)
                TableColumn("Exp", sortUsing: FrameSort(column: .exposure)) { r in Text(Format.number(r.meta?.exposure, digits: 0, suffix: "s")).monospacedDigit() }
                    .width(44)
                TableColumn("Bkg", sortUsing: FrameSort(column: .background)) { r in
                    FlaggedCell(text: Format.number(r.analysis?.background, digits: 0), flagged: r.flags.contains(.background))
                }
                .width(52)
                TableColumn("FWHM″", sortUsing: FrameSort(column: .fwhm)) { r in
                    FlaggedCell(text: Format.number(r.analysis?.stars?.fwhmArcsec ?? r.analysis?.stars?.fwhm, digits: 2),
                                flagged: r.flags.contains(.fwhm))
                }
                .width(52)
                TableColumn("★", sortUsing: FrameSort(column: .stars)) { r in
                    FlaggedCell(text: r.analysis?.stars.map { "\($0.count)" } ?? "–", flagged: r.flags.contains(.stars))
                }
                .width(44)
                TableColumn("Ecc", sortUsing: FrameSort(column: .eccentricity)) { r in
                    FlaggedCell(text: Format.number(r.analysis?.stars?.eccentricity, digits: 2), flagged: r.flags.contains(.eccentricity))
                }
                .width(40)
                TableColumn("Status", sortUsing: FrameSort(column: .status)) { r in StatusBadge(record: r) }
                    .width(64)
            }
            // Le frecce cambiano la selezione dai comandi del menu, non dalla tabella: senza questo la riga
            // selezionata uscirebbe dal fondo. Senza anchor scorre solo quanto basta a mostrarla.
            .onChange(of: model.selection) { _, id in
                if let id { proxy.scrollTo(id) }
            }
            // Dopo un riordino dall'intestazione la riga selezionata resta in vista: si scorre al giro
            // successivo, quando la tabella ha già spostato le righe.
            .onChange(of: model.sortOrder) {
                guard let id = model.selection else { return }
                DispatchQueue.main.async { proxy.scrollTo(id) }
            }
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
