import FitsCullCore
import SwiftUI

struct TrashFallbackView: View {
    @Environment(SessionModel.self) private var model
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Trash Not Available", systemImage: "exclamationmark.triangle")
                .font(.title3.bold())
            Text("\(model.trashFallback.count) files can't be moved to the Trash. This often happens with network folders (NAS).")
            if let reason = model.trashFallbackReason {
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
            Text("What do you want to do with these files?")
            HStack {
                Button("Cancel", role: .cancel) { model.trashFallback = [] }
                Spacer()
                Button("Delete Permanently…", role: .destructive) { confirmDelete = true }
                Button("Move to \(TrashService.rejectFolderName)/") { model.moveFallbackToRejectFolder() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .confirmationDialog("Permanently delete \(model.trashFallback.count) files?", isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Delete Permanently", role: .destructive) { model.deleteFallbackPermanently() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(Format.bytes(model.trashFallbackBytes)). This can't be undone.")
        }
    }
}
