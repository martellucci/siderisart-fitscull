import FitsCullCore
import SwiftUI

struct ContentView: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HSplitView {
                FrameListView()
                    .frame(minWidth: 380, idealWidth: 440, maxWidth: 600)
                MainPane()
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                InspectorView()
                    .frame(minWidth: 240, idealWidth: 290, maxWidth: 380)
            }
            HintBar()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { model.chooseFolder() } label: { Label("Apri cartella", systemImage: "folder") }
            }
            ToolbarItemGroup {
                Picker("Tipo", selection: $model.typeFilter) {
                    Text("Tutti").tag(ImageType?.none)
                    ForEach(model.availableTypes, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
                .pickerStyle(.menu)
                Picker("Ordina", selection: $model.sortKey) {
                    ForEach(SortKey.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                Picker("Vista", selection: $model.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle(model.folder?.lastPathComponent ?? "FitsCull")
        .navigationSubtitle(model.records.isEmpty ? ""
            : "\(model.records.count) file · \(model.rejectedCount) scartati · \(Format.bytes(model.totalBytes))")
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

struct MainPane: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        switch model.viewMode {
        case .review: ImageCanvasView()
        case .session: SessionChartsView()
        }
    }
}

struct HintBar: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            Text("←/→ naviga · X scarta · Spazio 1:1 · S stretch \(model.stretchEnabled ? "on" : "off") · L canali \(model.linkedChannels ? "collegati" : "separati")")
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
