import SwiftUI

@main
struct AppMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = ItemStore.sample()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 560)
                .onAppear { appDelegate.attach(store: store) }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
