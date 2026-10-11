import SwiftUI

struct ReviewCommands: Commands {
    let model: SessionModel

    var body: some Commands {
        CommandMenu("Revisione") {
            Button("File precedente") { model.move(-1) }.keyboardShortcut(.leftArrow, modifiers: [])
            Button("File successivo") { model.move(1) }.keyboardShortcut(.rightArrow, modifiers: [])
            Button("File precedente (↑)") { model.move(-1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("File successivo (↓)") { model.move(1) }.keyboardShortcut(.downArrow, modifiers: [])
            Divider()
            Button("Scarta / ripristina") { model.toggleReject() }.keyboardShortcut("x", modifiers: [])
            Button("Zoom 1:1") { model.actualSize.toggle() }.keyboardShortcut(.space, modifiers: [])
            Button("Stretch automatico") { model.stretchEnabled.toggle() }.keyboardShortcut("s", modifiers: [])
            Button("Canali collegati / separati") { model.linkedChannels.toggle() }.keyboardShortcut("l", modifiers: [])
            Divider()
            Button("Revisione") { model.viewMode = .review }.keyboardShortcut("1")
            Button("Sessione") { model.viewMode = .session }.keyboardShortcut("2")
        }
    }
}
