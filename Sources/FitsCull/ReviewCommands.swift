import SwiftUI

struct ReviewCommands: Commands {
    let model: SessionModel

    var body: some Commands {
        CommandMenu("Revisione") {
            Button("File precedente") { model.move(-1) }.keyboardShortcut(.leftArrow, modifiers: [])
            Button("File successivo") { model.move(1) }.keyboardShortcut(.rightArrow, modifiers: [])
            Button("File precedente (↑)") { model.move(-1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("File successivo (↓)") { model.move(1) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("Primo file") { model.moveToFirst() }.keyboardShortcut(.home, modifiers: [])
            Button("Ultimo file") { model.moveToLast() }.keyboardShortcut(.end, modifiers: [])
            Divider()
            Button("Scarta / ripristina") { model.toggleReject() }.keyboardShortcut("x", modifiers: [])
            Button("Adatta / 100%") { model.zoom = model.zoom == .fit ? .full : .fit }
                .keyboardShortcut(.space, modifiers: [])
            Button("Zoom adatta") { model.zoom = .fit }.keyboardShortcut("0")
            Button("Zoom 50%") { model.zoom = .half }
            Button("Zoom 100%") { model.zoom = .full }
            Button("Stretch automatico") { model.stretchEnabled.toggle() }.keyboardShortcut("s", modifiers: [])
            Button("Canali collegati / separati") { model.linkedChannels.toggle() }.keyboardShortcut("l", modifiers: [])
            Divider()
            Button("Sposta il file corrente nel Cestino…") { model.requestTrashCurrent() }
                .keyboardShortcut(.delete, modifiers: .command)
            Button("Sposta tutti gli scartati nel Cestino…") { model.requestTrash() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            Divider()
            Button("Revisione") { model.viewMode = .review }.keyboardShortcut("1")
            Button("Sessione") { model.viewMode = .session }.keyboardShortcut("2")
        }
    }
}
