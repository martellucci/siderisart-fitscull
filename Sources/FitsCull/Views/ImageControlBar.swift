import SwiftUI

/// Barra sotto l'immagine: navigazione, zoom, scarto e cestino del file corrente.
struct ImageControlBar: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let rejected = model.selectedRecord?.rejected ?? false
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Button { model.moveToFirst() } label: { Image(systemName: "backward.end.fill") }
                    .help("Primo file (Inizio)")
                Button { model.move(-1) } label: { Image(systemName: "chevron.left") }
                    .help("File precedente (←)")
                Text(model.positionText)
                    .monospacedDigit()
                    .frame(minWidth: 72)
                Button { model.move(1) } label: { Image(systemName: "chevron.right") }
                    .help("File successivo (→)")
                Button { model.moveToLast() } label: { Image(systemName: "forward.end.fill") }
                    .help("Ultimo file (Fine)")
            }
            Divider().frame(height: 18)
            Picker("Zoom", selection: $model.zoom) {
                Label("Adatta", systemImage: "arrow.up.left.and.arrow.down.right").tag(ZoomMode.fit)
                Text("50%").tag(ZoomMode.half)
                Text("100%").tag(ZoomMode.full)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Adatta / 50% / 100% (Spazio alterna adatta e 100%)")
            Divider().frame(height: 18)
            Button { model.toggleReject() } label: {
                Label(rejected ? "Ripristina" : "Scarta", systemImage: rejected ? "arrow.uturn.backward.circle" : "xmark.circle")
            }
            .help("Segna o ripristina il file (X)")
            Button(role: .destructive) { model.requestTrashCurrent() } label: {
                Image(systemName: "trash")
            }
            .help("Sposta il file corrente nel Cestino… (⌘⌫)")
        }
        .buttonStyle(.borderless)
        .disabled(model.selectedRecord == nil)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
