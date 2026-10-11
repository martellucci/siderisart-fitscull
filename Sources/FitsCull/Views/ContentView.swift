import FitsCullCore
import SwiftUI

struct ContentView: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        HSplitView {
            FrameListView()
                .frame(minWidth: 380, idealWidth: 440, maxWidth: 600)
            Text(model.selectedRecord?.id.lastPathComponent ?? "Apri una cartella con ⌘O")
                .foregroundStyle(.secondary)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(model.folder?.lastPathComponent ?? "FitsCull")
        .overlay {
            if let message = model.loadingMessage {
                ProgressView(message).padding().background(.regularMaterial, in: .rect(cornerRadius: 10))
            }
        }
        .alert("Attenzione", isPresented: Binding(get: { model.errorMessage != nil },
                                                  set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
