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

    private func zoomed(_ image: CGImage, scale: CGFloat) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Image(decorative: image, scale: scale).interpolation(.none)
        }
        .defaultScrollAnchor(.center)
    }

    @ViewBuilder
    private func content(for record: FrameRecord) -> some View {
        if case .failed(let message) = record.status {
            VStack(spacing: 10) {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.white)
                Button("Riprova") { model.retry(record.id) }
            }
        } else if let preview = model.previews[record.id] {
            let backing = NSScreen.main?.backingScaleFactor ?? 2
            switch model.zoom {
            case .fit:
                Image(decorative: preview.image, scale: 1)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
            case .half:
                zoomed(preview.image, scale: backing)
            case .full:
                if let full = model.fullResolution, full.url == record.id {
                    zoomed(full.preview.image, scale: backing)
                } else {
                    // In attesa della piena risoluzione: anteprima ingrandita 2× alla stessa scala.
                    zoomed(preview.image, scale: backing / 2)
                        .overlay(alignment: .topLeading) {
                            Label("Caricamento 100%…", systemImage: "hourglass")
                                .font(.caption)
                                .padding(6)
                                .background(.regularMaterial, in: .rect(cornerRadius: 6))
                                .padding()
                        }
                }
            }
        } else {
            ProgressView().controlSize(.large).tint(.white)
        }
    }
}
