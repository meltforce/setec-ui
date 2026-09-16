import AppKit

/// Owns what SwiftUI's `App` cannot: the Dock and termination policy, and the
/// DEBUG-only `DebugServer` the agent talks to.
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

    /// Registers the app's state and actions with the debug endpoint. Values
    /// never reach it — the state is names, counts and version numbers.
    func attach(store: SecretStore, access: AccessStore) {
        #if DEBUG
        DebugServer.shared.register(state: "secrets") { store.snapshot() }
        DebugServer.shared.register(state: "access") {
            [
                "state": String(describing: access.state),
                "rules": access.policy?.rules.count ?? 0,
            ]
        }
        DebugServer.shared.register(action: "select") { params in
            guard let name = params["name"] as? String else { throw DebugServer.Failure.badParams("name") }
            // Reported rather than set silently: a name the store does not hold
            // leaves the detail column empty, which reads as a broken view.
            guard store.secrets.contains(where: { $0.name == name }) else {
                throw DebugServer.Failure.unknown("secret \(name)")
            }
            store.selectedName = name
            return ["selected": name]
        }
        DebugServer.shared.register(action: "scope") { params in
            guard let value = params["value"] as? String else { throw DebugServer.Failure.badParams("value") }
            store.scope = Self.scope(from: value)
            return ["scope": store.scope.title]
        }
        DebugServer.shared.register(action: "search") { params in
            store.query = params["query"] as? String ?? ""
            return ["visible": store.visible.count]
        }
        // The app ships a light and a dark palette. The system appearance is
        // the operator's setting, so this is how the agent and a test look at
        // the second one without changing it. DEBUG only.
        DebugServer.shared.register(action: "appearance") { params in
            let name = params["name"] as? String ?? "system"
            NSApp.appearance = switch name {
            case "dark": NSAppearance(named: .darkAqua)
            case "light": NSAppearance(named: .aqua)
            default: nil
            }
            return ["appearance": name]
        }
        DebugServer.shared.register(action: "sheet") { params in
            let kind = params["kind"] as? String
            store.sheet = Self.sheet(named: kind, selected: store.selectedName)
            return ["sheet": store.sheet?.id ?? "none"]
        }
        #endif
    }

    #if DEBUG
    private static func scope(from value: String) -> Scope {
        if value == "all" {
            return .all
        }
        if let filter = SmartFilter(rawValue: value) {
            return .filter(filter)
        }
        return .group(value)
    }

    private static func sheet(named kind: String?, selected: String?) -> SecretStore.Sheet? {
        switch kind {
        case "new": .newSecret
        case "version": selected.map { SecretStore.Sheet.newVersion($0) }
        case "delete": selected.map { SecretStore.Sheet.deleteSecret($0) }
        default: nil
        }
    }
    #endif
}
