import SwiftUI

/// The middle column: one card per secret, the scope title and the sort
/// control above it. Nothing here fetches a value — a card is rendered from
/// the metadata `list` already returned.
struct SecretListView: View {
    @Environment(SecretStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Group {
            if let progress = store.reuseProgress {
                scanning(progress)
            } else if needsScan {
                scanPrompt
            } else if store.visible.isEmpty {
                emptyState
            } else {
                List(store.visible, selection: $store.selectedName) { secret in
                    SecretCard(
                        secret: secret,
                        selected: secret.name == store.selectedName,
                        reused: store.reusedNames.contains(secret.name)
                    )
                    .tag(secret.name)
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .accessibilityIdentifier("secrets.list")
            }
        }
        .background(Palette.listSurface)
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
    }

    private var header: some View {
        ColumnHeader {
            Text(verbatim: store.listTitle)
                .font(Typeface.ui(12.5, .semibold))
                .foregroundStyle(Palette.textControl)
                .lineLimit(1)
            Spacer(minLength: 0)
            Menu {
                Picker("Sort", selection: sortBinding) {
                    ForEach(SecretSort.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text(verbatim: store.sort.shortTitle)
                    .font(Typeface.meta)
                    .foregroundStyle(Palette.textQuaternary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityIdentifier("secrets.sort")
        }
    }

    /// True while the reuse filter is selected and no scan has been made. The
    /// column says what the scan costs instead of showing an empty result,
    /// because an empty list here would claim that nothing is reused.
    private var needsScan: Bool {
        store.scope == .filter(.reusedValue) && store.reuseScan == nil && store.query.isEmpty
    }

    private var scanPrompt: some View {
        ContentUnavailableView {
            Label("Not scanned yet", systemImage: "doc.on.doc")
        } description: {
            Text(verbatim: """
            Finding reused values means reading every value: setec's list carries no digest, so \
            this fetches all \(store.secrets.count) secrets, hashes each one and keeps the digest \
            alone. Every read is a get the server can audit. Nothing is written to disk.
            """)
        } actions: {
            Button("Scan \(store.secrets.count) secrets") {
                Task { await store.scanForReuse() }
            }
            .accessibilityIdentifier("secrets.scanReuse")
        }
    }

    private func scanning(_ progress: SecretStore.ReuseProgress) -> some View {
        VStack(spacing: 12) {
            ProgressView(value: Double(progress.done), total: Double(progress.total))
                .frame(width: 180)
            Text(verbatim: "Read \(progress.done) of \(progress.total)")
                .font(Typeface.meta)
                .foregroundStyle(Palette.textQuaternary)
            Button("Stop") { store.cancelReuseScan() }
                .accessibilityIdentifier("secrets.scanReuse.stop")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("secrets.scanning")
    }

    private var sortBinding: Binding<SecretSort> {
        Binding(get: { store.sort }, set: { store.sort = $0 })
    }

    @ViewBuilder
    private var emptyState: some View {
        switch store.loading {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("secrets.loading")
        case let .failed(message):
            ContentUnavailableView {
                Label("Cannot reach the server", systemImage: "network.slash")
            } description: {
                Text(verbatim: message)
            } actions: {
                Button("Try Again") { Task { await store.refresh() } }
                    .accessibilityIdentifier("secrets.retry")
            }
        case .idle, .loaded:
            if store.query.isEmpty {
                ContentUnavailableView {
                    Label("No secrets here", systemImage: "key")
                } description: {
                    Text("This scope holds no secret. Create one with New secret.")
                } actions: {
                    Button("New Secret…") { store.sheet = .newSecret }
                        .accessibilityIdentifier("secrets.empty.new")
                }
            } else {
                ContentUnavailableView.search(text: store.query)
            }
        }
    }
}

/// Line 1 is the name, split into the mono prefix and the mono leaf. Line 2
/// carries the active version, the version count, and the one condition the
/// metadata supports.
struct SecretCard: View {
    let secret: Secret
    let selected: Bool
    var reused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 0) {
                if !secret.prefix.isEmpty {
                    Text(verbatim: secret.prefix)
                        .font(Typeface.monoPrefix)
                        .foregroundStyle(Palette.textQuaternary)
                }
                Text(verbatim: secret.leaf)
                    .font(Typeface.monoLeaf)
                    .foregroundStyle(Palette.textLeaf)
            }
            .lineLimit(1)
            .truncationMode(.middle)
            HStack(spacing: 8) {
                VersionChip(version: secret.activeVersion)
                Text(verbatim: versionCount)
                    .font(Typeface.meta)
                    .foregroundStyle(Palette.textQuaternary)
                Spacer(minLength: 0)
                if reused {
                    Text("reused")
                        .font(Typeface.meta)
                        .foregroundStyle(Palette.destructiveLabel)
                } else if !secret.latestIsActive {
                    Text(verbatim: "v\(secret.latestVersion) not active")
                        .font(Typeface.meta)
                        .foregroundStyle(Palette.rotationDue)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Palette.selectedRow : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(selected ? Palette.selectionRing : .clear, lineWidth: 1)
        )
        .accessibilityIdentifier("secrets.row.\(secret.name)")
    }

    private var versionCount: String {
        secret.versions.count == 1 ? "1 version" : "\(secret.versions.count) versions"
    }
}
