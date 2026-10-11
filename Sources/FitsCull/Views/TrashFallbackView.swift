import FitsCullCore
import SwiftUI

struct TrashFallbackView: View {
    @Environment(SessionModel.self) private var model
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Cestino non disponibile", systemImage: "exclamationmark.triangle")
                .font(.title3.bold())
            Text("\(model.trashFallback.count) file non possono essere spostati nel Cestino. Succede spesso con le cartelle di rete (NAS).")
            if let reason = model.trashFallbackReason {
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
            Text("Cosa vuoi fare con questi file?")
            HStack {
                Button("Annulla", role: .cancel) { model.trashFallback = [] }
                Spacer()
                Button("Elimina definitivamente…", role: .destructive) { confirmDelete = true }
                Button("Sposta in \(TrashService.rejectFolderName)/") { model.moveFallbackToRejectFolder() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .confirmationDialog("Eliminare definitivamente \(model.trashFallback.count) file?", isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Elimina definitivamente", role: .destructive) { model.deleteFallbackPermanently() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("\(Format.bytes(model.trashFallbackBytes)). L'operazione non si può annullare.")
        }
    }
}
