import AppKit
import FitsCullCore
import SwiftUI

struct ImageCanvasView: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        ZStack {
            Color.black
            if let record = model.selectedRecord {
                content(for: record)
                if record.rejected {
                    VStack {
                        HStack {
                            Spacer()
                            Text("SCARTATO")
                                .font(.headline)
                                .padding(6)
                                .background(Color.red.opacity(0.85), in: .rect(cornerRadius: 6))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding()
                }
            } else {
                Text("Apri una cartella con ⌘O").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func content(for record: FrameRecord) -> some View {
        if case .failed(let message) = record.status {
            VStack(spacing: 10) {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.white)
                Button("Riprova") { model.retry(record.id) }
            }
        } else if let preview = model.previews[record.id] {
            if model.actualSize {
                ScrollView([.horizontal, .vertical]) {
                    Image(decorative: preview.image, scale: NSScreen.main?.backingScaleFactor ?? 2)
                        .interpolation(.none)
                }
            } else {
                Image(decorative: preview.image, scale: 1)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            ProgressView().controlSize(.large).tint(.white)
        }
    }
}
