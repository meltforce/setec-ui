import SwiftUI

/// Menu commands. Each one reaches its handler through a focused value, so a
/// command is enabled exactly when a scene that provides the value is focused.
/// A shortcut that "does nothing" is a missing focused value, not a wrong key.
struct AppCommands: Commands {
    @FocusedValue(\.itemActions) private var itemActions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Item") { itemActions?.newItem() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(itemActions == nil)
        }
        CommandMenu("Item") {
            Button("Next") { itemActions?.next() }
                .keyboardShortcut("j", modifiers: .command)
                .disabled(itemActions == nil)
            Button("Previous") { itemActions?.previous() }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(itemActions == nil)
            Divider()
            Button("Toggle Inspector") { itemActions?.toggleInspector() }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(itemActions == nil)
        }
    }
}

/// The actions a focused scene offers to the menu bar.
struct ItemActions {
    var newItem: () -> Void
    var next: () -> Void
    var previous: () -> Void
    var toggleInspector: () -> Void
}

extension FocusedValues {
    @Entry var itemActions: ItemActions?
}
