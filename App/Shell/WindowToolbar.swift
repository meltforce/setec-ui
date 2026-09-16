import SwiftUI

/// Refresh and New secret. Both are plain `Button`s in the system's toolbar
/// styles: macOS draws a toolbar item's own background, and a custom
/// `ButtonStyle` paints a second one inside it — the result reads as a broken
/// control rather than a styled one.
///
/// The server and the tailnet identity are not here. They are one value each,
/// neither changes while the window is open, and both live in Settings.
struct WindowToolbar: ToolbarContent {
    @Environment(SecretStore.self) private var store

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await store.refresh() }
            }
            .accessibilityIdentifier("toolbar.refresh")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("New Secret", systemImage: "plus") {
                store.sheet = .newSecret
            }
            // The one creating action in the window; it carries its label
            // rather than reducing to a glyph the way Refresh does.
            .labelStyle(.titleAndIcon)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("toolbar.newSecret")
        }
    }
}
