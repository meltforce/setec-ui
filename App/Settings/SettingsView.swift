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
                    prompt: Text(verbatim: ServerSetting.example)
                )
                .accessibilityIdentifier("settings.server")
                .disabled(ServerSetting.isOverriddenByEnvironment)
                HStack {
                    Button("Apply") { apply() }
                        .disabled(ServerSetting.isOverriddenByEnvironment || parsed == nil)
                        .accessibilityIdentifier("settings.server.apply")
                    Button("Clear") { clear() }
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
        .onAppear { draft = stored.isEmpty ? (store.server?.absoluteString ?? "") : stored }
    }

    private var parsed: URL? {
        ServerSetting.parse(draft)
    }

    private var reachability: String {
        switch store.loading {
        case .loaded: "Yes — \(store.secrets.count) secrets visible"
        case .loading: "Checking…"
        case .idle: "Not contacted yet"
        case .unconfigured: "No server named"
        case .failed: "No"
        }
    }

    private var footer: String {
        if ServerSetting.isOverriddenByEnvironment {
            return """
            SETEC_SERVER is set in the environment and decides, so this field \
            has no effect in this launch. The window talks to \
            \(store.server?.absoluteString ?? "no server").
            """
        }
        return """
        The app carries no built-in server, so this field or SETEC_SERVER names one. \
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

    private func clear() {
        stored = ""
        draft = ""
        store.forgetServer()
        status = "Cleared"
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
            Section {
                LabeledContent("Scope needed") {
                    Text(verbatim: TailnetPolicyClient.requiredScope)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("settings.access.requiredScope")
                }
                LabeledContent("Reads") {
                    Text(verbatim: "GET \(TailnetPolicyClient.policyURL.path())")
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Client carries") {
                    grantedScopes
                }
            } header: {
                Text("Rights")
            } footer: {
                Text("""
                One scope, for one endpoint. The app makes no device, DNS or route call, so a client \
                scoped to more than this is scoped wider than it needs to be. A client without the \
                scope is reported as such rather than as a bare 403.
                """)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            draftID = storedID
            draftSecret = storedSecret
        }
    }

    /// What the configured client actually carries, once a token has been
    /// exchanged — so a wrongly scoped client can be seen instead of guessed
    /// at. The scope the app needs is marked.
    @ViewBuilder
    private var grantedScopes: some View {
        if access.scopes.isEmpty {
            Text(verbatim: access.state == .loaded ? "not reported" : "not read yet")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.access.grantedScopes")
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(access.scopes, id: \.self) { scope in
                    let needed = scope == TailnetPolicyClient.requiredScope
                    Text(verbatim: needed ? "\(scope)  ✓ used" : scope)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(needed ? Color.primary : .secondary)
                }
            }
            .accessibilityIdentifier("settings.access.grantedScopes")
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
            let client = store.server.flatMap { server in
                AccessSetting.resolve().map {
                    TailnetPolicyClient(setec: SetecClient(server: server), names: $0)
                }
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
