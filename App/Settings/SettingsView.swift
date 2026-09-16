import SwiftUI

/// The Settings scene (⌘,). Preferences go here, not inline in the main
/// window. Plain values use `@AppStorage`; secrets use `Keychain`.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            AccountSettings()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .frame(width: 480, height: 300)
    }
}

struct GeneralSettings: View {
    @AppStorage("showArchive") private var showArchive = true
    @AppStorage("refreshMinutes") private var refreshMinutes = 15

    var body: some View {
        Form {
            Toggle("Show the Archive section", isOn: $showArchive)
                .accessibilityIdentifier("settings.showArchive")
            Stepper("Refresh every \(refreshMinutes) min", value: $refreshMinutes, in: 1 ... 120)
                .accessibilityIdentifier("settings.refreshMinutes")
        }
        .formStyle(.grouped)
    }
}

struct AccountSettings: View {
    @State private var token = ""
    @State private var status = ""

    private let keychainKey = "api-token"

    var body: some View {
        Form {
            Section {
                SecureField(
                    "API token",
                    text: $token,
                    prompt: Text(hasToken ? "•••••••• (saved)" : "Paste a token")
                )
                .accessibilityIdentifier("settings.token")
                HStack {
                    Button("Save") { save() }
                        .disabled(token.isEmpty)
                        .accessibilityIdentifier("settings.token.save")
                    Button("Remove", role: .destructive) { remove() }
                        .disabled(!hasToken)
                        .accessibilityIdentifier("settings.token.remove")
                    Spacer()
                    Text(status).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Stored in the login keychain under \(Keychain.service).")
            }
        }
        .formStyle(.grouped)
    }

    private var hasToken: Bool {
        (try? Keychain.read(key: keychainKey)) != nil
    }

    private func save() {
        do {
            try Keychain.write(key: keychainKey, value: token)
            token = ""
            status = "Saved"
        } catch {
            status = error.localizedDescription
        }
    }

    private func remove() {
        do {
            try Keychain.delete(key: keychainKey)
            status = "Removed"
        } catch {
            status = error.localizedDescription
        }
    }
}
