import SwiftUI

/// The selected secret: what it is, what its value is once asked for, which
/// versions exist, and who else in the tailnet may touch it.
struct DetailView: View {
    @Environment(SecretStore.self) private var store

    var body: some View {
        Group {
            if let secret = store.selected {
                content(for: secret)
            } else {
                ContentUnavailableView {
                    Label("No secret selected", systemImage: "key")
                } description: {
                    Text("Pick a secret in the list to see its versions and its access rules.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.panel)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DetailStatusBar()
        }
    }

    private func content(for secret: Secret) -> some View {
        VStack(spacing: 0) {
            DetailActionBar(secret: secret)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    DetailTitle(secret: secret)
                    ValueSection(secret: secret)
                    VersionsSection(secret: secret)
                    AccessSection(secret: secret)
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The detail column's header bar, on the same line as the other two columns':
/// the group the secret sits in on the left, what can be done to it on the
/// right. The name itself is in the body, where it is the heading of what is
/// shown beneath it.
struct DetailActionBar: View {
    @Environment(SecretStore.self) private var store
    let secret: Secret

    var body: some View {
        ColumnHeader(background: Palette.panel) {
            Text(verbatim: secret.prefix.isEmpty ? "Ungrouped" : secret.prefix)
                .font(Typeface.mono(12.5))
                .foregroundStyle(Palette.textQuaternary)
                .lineLimit(1)
            Spacer(minLength: 0)
            // The system's glass styles, not the app's own: these sit in a
            // bar the window draws, where a hand-painted background reads as
            // a second control behind the first. Copying is not here — it is
            // on the value panel itself, where the value is.
            Button("New version …") {
                store.sheet = .newVersion(secret.name)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .accessibilityIdentifier("detail.newVersion")

            Menu {
                Button("Copy name") {
                    SecretPasteboard.copyPlain(secret.name)
                }
                Divider()
                Button("Delete secret …", role: .destructive) {
                    store.sheet = .deleteSecret(secret.name)
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .controlSize(.small)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityIdentifier("detail.more")
        }
    }
}

/// The secret's name and what the metadata says about it, at the top of the
/// scrollable body.
struct DetailTitle: View {
    let secret: Secret

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: secret.leaf)
                .font(Typeface.detailTitle)
                .tracking(Typeface.detailTitleTracking)
                .foregroundStyle(Palette.textPrimary)
                .textSelection(.enabled)
                .accessibilityIdentifier("detail.title")
            metaRow
                .padding(.top, 8)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text("Active:")
            Text(verbatim: "v\(secret.activeVersion)")
                .font(Typeface.ui(12, .semibold))
                .foregroundStyle(Palette.accent)
                .tabularDigits()
            Text(verbatim: "·")
            Text(verbatim: secret.versions.count == 1 ? "1 version" : "\(secret.versions.count) versions")
            if !secret.latestIsActive {
                Text(verbatim: "·")
                Text(verbatim: "v\(secret.latestVersion) is newer and not active")
                    .foregroundStyle(Palette.rotationDue)
            }
        }
        .font(Typeface.label)
        .foregroundStyle(Palette.textTertiary)
        .accessibilityIdentifier("detail.meta")
    }
}

struct DetailStatusBar: View {
    @Environment(SecretStore.self) private var store

    var body: some View {
        HStack {
            Text(verbatim: store.lastCall)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("detail.lastCall")
            Spacer(minLength: 12)
            Text("Values are never cached on disk")
        }
        .font(Typeface.meta)
        .foregroundStyle(Palette.textQuaternary)
        .padding(.horizontal, 26)
        .frame(height: 30)
        .frame(maxWidth: .infinity)
        .background(Palette.listSurface)
        .hairline(.top)
    }
}
