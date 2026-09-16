import SwiftUI

/// The toolbar the design draws by hand, built from the real window's toolbar:
/// the server pill, the tailnet identity, Refresh and New secret. The traffic
/// lights and the drag region come from the window.
struct WindowToolbar: ToolbarContent {
    @Environment(SecretStore.self) private var store
    @Environment(\.openSettings) private var openSettings

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                openSettings()
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(reachable ? Palette.granted : Palette.textMeta)
                        .frame(width: 7, height: 7)
                    Text(verbatim: store.server.host() ?? store.server.absoluteString)
                        .font(Typeface.controlEmphasis)
                        .foregroundStyle(Palette.textControl)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Palette.textQuaternary)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .help("The setec server this window talks to. Opens Settings.")
            .accessibilityIdentifier("toolbar.server")
        }
        ToolbarItem(placement: .navigation) {
            Text(verbatim: identityLabel)
                .font(Typeface.label)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize()
                .help("The tailnet identity setec authenticates this window as.")
                .accessibilityIdentifier("toolbar.identity")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Refresh") {
                Task { await store.refresh() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("toolbar.refresh")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                store.sheet = .newSecret
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text("New secret")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("toolbar.newSecret")
        }
    }

    private var reachable: Bool {
        store.loading == .loaded
    }

    private var identityLabel: String {
        guard let identity = store.identity else { return "Identity unknown" }
        return "Signed in as \(identity.shortLogin)"
    }
}
