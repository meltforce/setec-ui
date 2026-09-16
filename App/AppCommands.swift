import SwiftUI

/// Menu commands. Each one reaches its handler through a focused value, so a
/// command is enabled exactly when a scene that provides the value is focused.
/// A shortcut that "does nothing" is a missing focused value, not a wrong key.
///
/// No shortcut here carries Shift. Two of them therefore carry Option, because
/// the plain ⌘ key they would otherwise want is already spoken for: ⌘N creates
/// a secret, so a version is ⌘⌥N, and ⌘C belongs to the text selection in the
/// value panel and in every sheet field, so copying the secret's value is ⌘⌥C.
struct AppCommands: Commands {
    @FocusedValue(\.secretActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Secret…") { actions?.newSecret() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions == nil)
            Button("New Version…") { actions?.newVersion() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(actions?.canActOnSecret != true)
        }
        CommandGroup(after: .textEditing) {
            Button("Find") { actions?.focusSearch() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions == nil)
        }
        CommandMenu("Secret") {
            Button("Copy Value") { actions?.copyValue() }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(actions?.canActOnSecret != true)
            Button("Reveal or Hide Value") { actions?.toggleReveal() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(actions?.canActOnSecret != true)
            Divider()
            Button("New Version…") { actions?.newVersion() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(actions?.canActOnSecret != true)
            Button("Delete Secret…") { actions?.deleteSecret() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(actions?.canActOnSecret != true)
            Divider()
            Button("Refresh") { actions?.refresh() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(actions == nil)
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
    var focusSearch: () -> Void
    var canActOnSecret: Bool
}

extension FocusedValues {
    @Entry var secretActions: SecretActions?
}
