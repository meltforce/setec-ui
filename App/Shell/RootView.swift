import SwiftUI

/// The window: a sidebar of groups and derived filters, a list of secrets, and
/// the detail column. Column widths follow the design (232 / 316 / rest); the
/// window chrome and the toolbar come from the real window, which is the one
/// abstraction the handoff makes.
struct RootView: View {
    @Environment(SecretStore.self) private var store
    @Environment(AccessStore.self) private var access
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 232, max: 300)
        } content: {
            SecretListView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 316, max: 420)
        } detail: {
            DetailView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar { WindowToolbar() }
        .navigationTitle(store.selected?.name ?? "Setec UI")
        .navigationSubtitle(subtitle)
        // In the toolbar rather than in the sidebar: it searches every secret
        // regardless of the selected group, so it belongs to the window and
        // not to the column that chooses a group.
        .searchable(
            text: $store.query,
            placement: .toolbar,
            prompt: Text("Search secrets")
        )
        .searchFocused($searchFocused)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let problem = store.problem {
                ProblemStrip(message: problem) { store.dismissProblem() }
            }
        }
        .sheet(item: $store.sheet) { sheet in
            switch sheet {
            case .newSecret:
                NewSecretSheet()
            case let .newVersion(name):
                NewVersionSheet(name: name)
            case let .deleteSecret(name):
                DeleteSecretSheet(name: name)
            case let .deleteVersion(name, version):
                DeleteVersionSheet(name: name, version: version)
            }
        }
        .focusedSceneValue(\.secretActions, SecretActions(
            newSecret: { store.sheet = .newSecret },
            newVersion: {
                if let name = store.selectedName {
                    store.sheet = .newVersion(name)
                }
            },
            deleteSecret: {
                if let name = store.selectedName {
                    store.sheet = .deleteSecret(name)
                }
            },
            refresh: { Task { await store.refresh() } },
            toggleReveal: { Task { store.revealed == nil ? await store.reveal() : store.hide() } },
            copyValue: { Task { await store.copyActiveValue() } },
            focusSearch: { searchFocused = true },
            canActOnSecret: store.selectedName != nil
        ))
        .task {
            await store.loadIdentity()
            await store.refresh()
            await access.load()
        }
    }

    private var subtitle: String {
        let count = store.visible.count
        return "\(count) secret\(count == 1 ? "" : "s") in \(store.listTitle)"
    }
}

/// The error surface the design does not carry. Loading, empty and error
/// states are flagged for design review in `ROADMAP.md`; this is the
/// placeholder, built in the established visual language.
struct ProblemStrip: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Palette.destructive)
                .frame(width: 7, height: 7)
            Text(message)
                .font(Typeface.meta)
                .foregroundStyle(Palette.textBody)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button("Dismiss", action: dismiss)
                .buttonStyle(LinkButtonStyle(size: 11.5, tint: Palette.textSecondary))
                .accessibilityIdentifier("problem.dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Palette.redHeaderFill)
        .hairline(.bottom, color: Palette.redRing)
    }
}
