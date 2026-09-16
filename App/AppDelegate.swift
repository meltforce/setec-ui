import AppKit

/// Owns what SwiftUI's `App` cannot: the Dock and termination policy, URL
/// events, and the DEBUG-only `DebugServer` the agent talks to.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.notice("launched \(Bundle.main.bundleIdentifier ?? "-", privacy: .public)")
        #if DEBUG
        DebugServer.shared.start()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Registers the app's state and actions with the debug endpoint. Called
    /// once the root view has its store. Compiles to nothing in Release.
    func attach(store: ItemStore) {
        #if DEBUG
        DebugServer.shared.register(state: "items") { store.snapshot() }
        DebugServer.shared.register(action: "select") { params in
            guard let id = params["id"] as? String else { throw DebugServer.Failure.badParams("id") }
            store.select(id: id)
            return ["selected": id]
        }
        DebugServer.shared.register(action: "add") { params in
            let title = params["title"] as? String ?? "Untitled"
            let item = store.add(title: title)
            return ["id": item.id]
        }
        #endif
    }
}
