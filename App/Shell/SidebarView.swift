import SwiftUI

/// Groups and derived filters. A group is not an object — it exists exactly as
/// long as a secret carries its prefix, so the rows are computed from the
/// names and there is nothing here to create or rename.
struct SidebarView: View {
    @Environment(SecretStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: scopeBinding) {
            Section {
                row(for: .all, glyph: "square.stack", label: "All secrets", count: store.secrets.count)
                ForEach(store.groupCounts, id: \.group) { entry in
                    row(
                        for: .group(entry.group),
                        glyph: "chevron.right",
                        label: "\(entry.group)/",
                        count: entry.count
                    )
                }
            } header: {
                Text("Namespaces").sectionHeaderStyle()
            }
            Section {
                ForEach(SmartFilter.allCases) { filter in
                    row(
                        for: .filter(filter),
                        dot: color(for: filter),
                        label: filter.title,
                        count: store.count(for: filter)
                    )
                }
            } header: {
                Text("Smart filters").sectionHeaderStyle()
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("sidebar.list")
        .safeAreaInset(edge: .top, spacing: 0) {
            ColumnHeader(background: .clear) {
                Text(verbatim: countLabel)
                    .font(Typeface.ui(12.5, .semibold))
                    .foregroundStyle(Palette.textControl)
                    .accessibilityIdentifier("sidebar.count")
                Spacer(minLength: 0)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter()
        }
    }

    private var countLabel: String {
        store.secrets.count == 1 ? "1 secret" : "\(store.secrets.count) secrets"
    }

    private var scopeBinding: Binding<Scope?> {
        Binding(
            get: { store.scope },
            set: { store.scope = $0 ?? .all }
        )
    }

    private func row(
        for scope: Scope,
        glyph: String? = nil,
        dot: Color? = nil,
        label: String,
        count: Int
    ) -> some View {
        HStack(spacing: 8) {
            if let dot {
                Circle().fill(dot).frame(width: 8, height: 8)
            } else if let glyph {
                Image(systemName: glyph)
                    .font(.system(size: 9, weight: .semibold))
                    // Not a palette colour: the sidebar style inverts the
                    // foreground of the selected row, and a fixed grey stays
                    // grey on the selection fill.
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
            }
            Text(verbatim: label)
                .font(Typeface.control)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(verbatim: "\(count)")
                .font(Typeface.badge)
                .tabularDigits()
                .foregroundStyle(.secondary)
        }
        .tag(scope)
        .accessibilityIdentifier("sidebar.\(identifier(for: scope))")
    }

    private func identifier(for scope: Scope) -> String {
        switch scope {
        case .all: "all"
        case let .group(group): "group.\(group)"
        case let .filter(filter): "filter.\(filter.rawValue)"
        }
    }

    private func color(for filter: SmartFilter) -> Color {
        switch filter {
        case .latestNotActive: Palette.filterDot
        case .multipleVersions: Palette.granted
        }
    }
}

/// Secret count on the left, last sync on the right. The time counts up on its
/// own, so a window left open does not claim a sync that is minutes old.
struct SidebarFooter: View {
    @Environment(SecretStore.self) private var store

    var body: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 5)) { context in
                Text(verbatim: syncLabel(now: context.date))
                    .accessibilityIdentifier("sidebar.synced")
            }
            Spacer()
        }
        .font(Typeface.badge)
        .foregroundStyle(Palette.textQuaternary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .hairline(.top, color: Palette.chromeBorder)
    }

    private func syncLabel(now: Date) -> String {
        switch store.loading {
        case .loading: "Syncing…"
        case .failed: "Sync failed"
        case .idle: "Not synced"
        case .loaded:
            store.lastSynced.map { "Synced \(RelativeTime.compact(since: $0, now: now))" } ?? "Synced"
        }
    }
}
