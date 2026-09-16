import SwiftUI

/// The Settings scene (⌘,). The only preference the app has is which setec
/// server it talks to; everything else it needs comes from the tailnet.
struct SettingsView: View {
    var body: some View {
        TabView {
            ServerSettings()
                .tabItem { Label("Server", systemImage: "server.rack") }
        }
        .frame(width: 520, height: 260)
    }
}

struct ServerSettings: View {
    @Environment(SecretStore.self) private var store
    @AppStorage(ServerSetting.defaultsKey) private var stored = ""
    @State private var draft = ""
    @State private var status = ""

    var body: some View {
        Form {
            Section {
                TextField(
                    "Server",
                    text: $draft,
                    prompt: Text(verbatim: ServerSetting.fallback.absoluteString)
                )
                .accessibilityIdentifier("settings.server")
                .disabled(ServerSetting.isOverriddenByEnvironment)
                HStack {
                    Button("Apply") { apply() }
                        .disabled(ServerSetting.isOverriddenByEnvironment || parsed == nil)
                        .accessibilityIdentifier("settings.server.apply")
                    Button("Use the default") { reset() }
                        .disabled(ServerSetting.isOverriddenByEnvironment || stored.isEmpty)
                        .accessibilityIdentifier("settings.server.reset")
                    Spacer()
                    Text(verbatim: status).foregroundStyle(.secondary)
                }
            } header: {
                Text("setec server")
            } footer: {
                Text(verbatim: footer)
            }
        }
        .formStyle(.grouped)
        .onAppear { draft = stored.isEmpty ? store.server.absoluteString : stored }
    }

    private var parsed: URL? {
        ServerSetting.parse(draft)
    }

    private var footer: String {
        if ServerSetting.isOverriddenByEnvironment {
            return """
            SETEC_SERVER is set in the environment and decides, so this field \
            has no effect in this launch. The window talks to \
            \(store.server.absoluteString).
            """
        }
        return """
        Identity comes from the local tailscaled, so there is nothing to sign in with. \
        SETEC_SERVER overrides this field when it is set.
        """
    }

    private func apply() {
        guard let url = parsed else {
            status = "Not a URL"
            return
        }
        stored = url.absoluteString
        store.use(server: url)
        status = "Applied"
    }

    private func reset() {
        stored = ""
        draft = ServerSetting.fallback.absoluteString
        store.use(server: ServerSetting.fallback)
        status = "Back to the default"
    }
}
