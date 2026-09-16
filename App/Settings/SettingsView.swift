import SwiftUI

/// The Settings scene (⌘,). The only preference the app has is which setec
/// server it talks to; everything else it needs comes from the tailnet.
struct SettingsView: View {
    var body: some View {
        TabView {
            ServerSettings()
                .tabItem { Label("Server", systemImage: "server.rack") }
            AccessMatrixSettings()
                .tabItem { Label("Access matrix", systemImage: "tablecells") }
        }
        .frame(width: 560, height: 360)
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
            Section {
                LabeledContent("Signed in as") {
                    Text(verbatim: store.identity?.loginName ?? "Identity unknown")
                        .accessibilityIdentifier("settings.identity")
                }
                LabeledContent("This machine") {
                    Text(verbatim: store.identity?.nodeName ?? "—")
                        .accessibilityIdentifier("settings.node")
                }
                LabeledContent("Reachable") {
                    Text(verbatim: reachability)
                        .accessibilityIdentifier("settings.reachable")
                }
            } header: {
                Text("Identity")
            } footer: {
                Text("""
                setec authorizes the caller by its tailnet identity, so there is nothing to sign in \
                with here. The identity comes from the local tailscaled.
                """)
            }
        }
        .formStyle(.grouped)
        .onAppear { draft = stored.isEmpty ? store.server.absoluteString : stored }
    }

    private var parsed: URL? {
        ServerSetting.parse(draft)
    }

    private var reachability: String {
        switch store.loading {
        case .loaded: "Yes — \(store.secrets.count) secrets visible"
        case .loading: "Checking…"
        case .idle: "Not contacted yet"
        case .failed: "No"
        }
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

/// Which two setec entries hold the Tailscale OAuth client the access matrix
/// reads the policy with. Clearing either field switches the matrix off; it
/// does not affect anything else the window does.
struct AccessMatrixSettings: View {
    @Environment(SecretStore.self) private var store
    @Environment(AccessStore.self) private var access
    @AppStorage(AccessSetting.clientIDKey) private var storedID = AccessSetting.defaultClientIDSecret
    @AppStorage(AccessSetting.clientSecretKey) private var storedSecret = AccessSetting.defaultClientSecretSecret
    @State private var draftID = ""
    @State private var draftSecret = ""
    @State private var status = ""

    var body: some View {
        Form {
            Section {
                TextField(
                    "Client ID entry",
                    text: $draftID,
                    prompt: Text(verbatim: AccessSetting.defaultClientIDSecret)
                )
                .accessibilityIdentifier("settings.access.id")
                TextField(
                    "Client secret entry",
                    text: $draftSecret,
                    prompt: Text(verbatim: AccessSetting.defaultClientSecretSecret)
                )
                .accessibilityIdentifier("settings.access.secret")
                HStack {
                    Button("Apply") { apply() }
                        .accessibilityIdentifier("settings.access.apply")
                    Button("Use the defaults") { reset() }
                        .accessibilityIdentifier("settings.access.reset")
                    Spacer()
                    Text(verbatim: status.isEmpty ? stateLabel : status)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.access.state")
                }
            } header: {
                Text("Tailscale OAuth client")
            } footer: {
                Text("""
                These are the names of two setec entries, not the credential itself. The app reads \
                them under this machine's tailnet identity and exchanges them for a token that reads \
                the tailnet policy file — setec has no policy endpoint of its own.

                Leave either field empty to switch the matrix off. The secret list, the versions and \
                every action keep working either way; only the grants of other principals need this.
                """)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            draftID = storedID
            draftSecret = storedSecret
        }
    }

    private var stateLabel: String {
        switch access.state {
        case .loaded: "Policy loaded"
        case .loading: "Reading…"
        case .idle: "Not read yet"
        case .disabled: "Switched off"
        case .failed: "Could not be read"
        }
    }

    private func apply() {
        storedID = draftID.trimmingCharacters(in: .whitespacesAndNewlines)
        storedSecret = draftSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        status = ""
        Task {
            let client = AccessSetting.resolve().map {
                TailnetPolicyClient(setec: SetecClient(server: store.server), names: $0)
            }
            await access.use(client: client)
        }
    }

    private func reset() {
        draftID = AccessSetting.defaultClientIDSecret
        draftSecret = AccessSetting.defaultClientSecretSecret
        apply()
    }
}
