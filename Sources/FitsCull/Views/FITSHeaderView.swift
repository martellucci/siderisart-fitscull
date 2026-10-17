import FitsCullCore
import SwiftUI

/// Finestra FITS Header: segue il file selezionato nella finestra principale.
struct FITSHeaderView: View {
    static let windowID = "fits-header"

    @Environment(SessionModel.self) private var model

    var body: some View {
        Group {
            if let record = model.selectedRecord, let header = record.header {
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(header.cards.enumerated()), id: \.offset) { _, card in
                            Text(card.raw.trimmingCharacters(in: .whitespaces))
                                .font(.system(.callout, design: .monospaced))
                                .fixedSize()
                        }
                    }
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(record.id.lastPathComponent)
                .navigationSubtitle("\(header.cards.count) cards")
            } else {
                Text("No FITS header").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("FITS Header")
            }
        }
        .frame(minWidth: 420, minHeight: 300)
    }
}
