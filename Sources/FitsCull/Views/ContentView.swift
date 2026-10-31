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
                    .frame(minWidth: 300, idealWidth: 330, maxWidth: 420)
            }
            HintBar()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { model.chooseFolder() } label: { Label("Open Folder", systemImage: "folder") }
            }
            ToolbarItemGroup {
                Picker("Type", selection: $model.typeFilter) {
                    Text("All").tag(ImageType?.none)
                    ForEach(model.availableTypes, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
                .pickerStyle(.menu)
                Picker("View", selection: $model.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle(model.folder?.lastPathComponent ?? "FitsCull")
        .navigationSubtitle(model.records.isEmpty ? ""
            : "\(model.records.count) files · \(model.rejectedCount) rejected · \(Format.bytes(model.totalBytes))")
        .overlay {
            if let message = model.loadingMessage {
                ProgressView(message).padding().background(.regularMaterial, in: .rect(cornerRadius: 10))
            }
        }
        .alert("Warning", isPresented: Binding(get: { model.errorMessage != nil },
                                                  set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog("Move \(model.rejectedCount) files to the Trash?", isPresented: $model.confirmTrash,
                            titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { model.performTrash() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(model.rejectedCount) files · \(Format.bytes(model.rejectedBytes)). You can recover them from the Trash in the Finder.")
        }
        .confirmationDialog("Move \"\(model.selectedRecord?.id.lastPathComponent ?? "")\" to the Trash?",
                            isPresented: $model.confirmTrashCurrent, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { model.performTrashCurrent() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(Format.bytes(model.selectedRecord?.file.size ?? 0)). You can recover it from the Trash in the Finder.")
        }
        .confirmationDialog("Convert \"\(model.selectedRecord?.id.lastPathComponent ?? "")\"?",
                            isPresented: $model.confirmConvertCurrent, titleVisibility: .visible) {
            ForEach(model.conversionTargets, id: \.self) { type in
                Button("Convert to \(type.label)") { model.performConvertCurrent(to: type) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A copy with the new type is created in the same folder. The original is not changed.")
        }
        .sheet(isPresented: Binding(get: { model.conversionFolder != nil },
                                    set: { if !$0 { model.conversionFolder = nil } })) {
            if let folder = model.conversionFolder { ConvertFolderView(folder: folder).environment(model) }
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
            Text("←/→ navigate · X reject · ⇧C type · Space fit/100% · ⌘⌫ trash · S stretch \(model.stretchEnabled ? "on" : "off") · L channels \(model.linkedChannels ? "linked" : "separate")")
            Spacer()
            Button("Move Rejected to Trash (\(model.rejectedCount))") { model.requestTrash() }
                .disabled(model.rejectedCount == 0)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
