import AppKit
import SwiftUI

@main
struct FitsCullApp: App {
    @State private var model = SessionModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("FitsCull") {
            ContentView()
                .environment(model)
                .frame(minWidth: 1100, minHeight: 650)
                .onAppear { NSApplication.shared.activate() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.saveCache()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Apri cartella…") { model.chooseFolder() }
                    .keyboardShortcut("o")
            }
            ReviewCommands(model: model)
        }
    }
}
