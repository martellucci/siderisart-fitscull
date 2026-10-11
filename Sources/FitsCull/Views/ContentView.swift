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
        .confirmationDialog("Spostare \(model.rejectedCount) file nel Cestino?", isPresented: $model.confirmTrash,
                            titleVisibility: .visible) {
            Button("Sposta nel Cestino", role: .destructive) { model.performTrash() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("\(model.rejectedCount) file · \(Format.bytes(model.rejectedBytes)). Potrai recuperarli dal Cestino del Finder.")
        }
        .confirmationDialog("Spostare \"\(model.selectedRecord?.id.lastPathComponent ?? "")\" nel Cestino?",
                            isPresented: $model.confirmTrashCurrent, titleVisibility: .visible) {
            Button("Sposta nel Cestino", role: .destructive) { model.performTrashCurrent() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("\(Format.bytes(model.selectedRecord?.file.size ?? 0)). Potrai recuperarlo dal Cestino del Finder.")
        }
        .sheet(isPresented: Binding(get: { !model.trashFallback.isEmpty },
                                    set: { if !$0 { model.trashFallback = [] } })) {
            TrashFallbackView().environment(model)
        }
    }
}

struct MainPane: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        switch model.viewMode {
        case .review:
            VStack(spacing: 0) {
                ImageCanvasView()
                ImageControlBar()
            }
        case .session: SessionChartsView()
        }
    }
}

struct HintBar: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            Text("←/→ naviga · X scarta · Spazio adatta/100% · ⌘⌫ cestino · S stretch \(model.stretchEnabled ? "on" : "off") · L canali \(model.linkedChannels ? "collegati" : "separati")")
            Spacer()
            Button("Sposta scartati nel Cestino (\(model.rejectedCount))") { model.requestTrash() }
                .disabled(model.rejectedCount == 0)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
