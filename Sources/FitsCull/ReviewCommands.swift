import SwiftUI

struct ReviewCommands: Commands {
    let model: SessionModel

    var body: some Commands {
        CommandMenu("Review") {
            Button("Previous File") { model.move(-1) }.keyboardShortcut(.leftArrow, modifiers: [])
            Button("Next File") { model.move(1) }.keyboardShortcut(.rightArrow, modifiers: [])
            Button("Previous File (↑)") { model.move(-1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("Next File (↓)") { model.move(1) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("First File") { model.moveToFirst() }.keyboardShortcut(.home, modifiers: [])
            Button("Last File") { model.moveToLast() }.keyboardShortcut(.end, modifiers: [])
            Divider()
            Button("Reject / Restore") { model.toggleReject() }.keyboardShortcut("x", modifiers: [])
            Button("Fit / 100%") { model.zoom = model.zoom == .fit ? .full : .fit }
                .keyboardShortcut(.space, modifiers: [])
            Button("Zoom to Fit") { model.zoom = .fit }.keyboardShortcut("0")
            Button("Zoom 50%") { model.zoom = .half }
            Button("Zoom 100%") { model.zoom = .full }
            Button("Auto Stretch") { model.stretchEnabled.toggle() }.keyboardShortcut("s", modifiers: [])
            Button("Linked / Separate Channels") { model.linkedChannels.toggle() }.keyboardShortcut("l", modifiers: [])
            Divider()
            Button("Move Current File to Trash…") { model.requestTrashCurrent() }
                .keyboardShortcut(.delete, modifiers: .command)
            Button("Move All Rejected to Trash…") { model.requestTrash() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            Divider()
            Button("Review View") { model.viewMode = .review }.keyboardShortcut("1")
            Button("Session View") { model.viewMode = .session }.keyboardShortcut("2")
        }
    }
}
