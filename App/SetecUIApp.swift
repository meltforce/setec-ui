import SwiftUI

@main
struct AppMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: SecretStore
    @State private var access: AccessStore

    init() {
        let store = SecretStore()
        let client = AccessSetting.resolve().map {
            TailnetPolicyClient(setec: SetecClient(server: store.server), names: $0)
        }
        _store = State(initialValue: store)
        _access = State(initialValue: AccessStore(client: client) { [weak store] in store?.identity })
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(access)
                .frame(minWidth: 1000, minHeight: 700)
                .onAppear { appDelegate.attach(store: store, access: access) }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
                .environment(store)
                .environment(access)
        }
    }
}
