import SwiftUI

/// Menu commands. Each one reaches its handler through a focused value, so a
/// command is enabled exactly when a scene that provides the value is focused.
/// A shortcut that "does nothing" is a missing focused value, not a wrong key.
struct AppCommands: Commands {
    @FocusedValue(\.secretActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Secret…") { actions?.newSecret() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions == nil)
        }
        CommandMenu("Secret") {
            Button("New Version…") { actions?.newVersion() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(actions?.canActOnSecret != true)
            Button("Copy Value") { actions?.copyValue() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(actions?.canActOnSecret != true)
            Button("Reveal or Hide Value") { actions?.toggleReveal() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(actions?.canActOnSecret != true)
            Divider()
            Button("Refresh") { actions?.refresh() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(actions == nil)
            Divider()
            Button("Delete Secret…") { actions?.deleteSecret() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(actions?.canActOnSecret != true)
        }
    }
}

/// The actions the focused window offers to the menu bar.
struct SecretActions {
    var newSecret: () -> Void
    var newVersion: () -> Void
    var deleteSecret: () -> Void
    var refresh: () -> Void
    var toggleReveal: () -> Void
    var copyValue: () -> Void
    var canActOnSecret: Bool
}

extension FocusedValues {
    @Entry var secretActions: SecretActions?
}
