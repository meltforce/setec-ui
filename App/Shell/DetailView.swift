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
            DetailHeader(secret: secret)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ValueSection(secret: secret)
                    VersionsSection(secret: secret)
                    AccessSection(secret: secret)
                }
                .padding(.horizontal, 26)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct DetailHeader: View {
    @Environment(SecretStore.self) private var store
    let secret: Secret

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                if !secret.prefix.isEmpty {
                    Text(verbatim: secret.prefix)
                        .font(Typeface.monoPrefix)
                        .foregroundStyle(Palette.textQuaternary)
                }
                Text(verbatim: secret.leaf)
                    .font(Typeface.detailTitle)
                    .tracking(Typeface.detailTitleTracking)
                    .foregroundStyle(Palette.textPrimary)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("detail.title")
                metaRow
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
            actions
        }
        .padding(.leading, 26)
        .padding(.trailing, 26)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .hairline(.bottom)
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

    private var actions: some View {
        HStack(spacing: 8) {
            Button(store.copyConfirmed ? "Copied ✓" : "Copy value") {
                Task { await store.copyActiveValue() }
            }
            .buttonStyle(PrimaryButtonStyle(height: 30))
            .disabled(store.isFetchingValue)
            .accessibilityIdentifier("detail.copy")

            Button("New version …") {
                store.sheet = .newVersion(secret.name)
            }
            .buttonStyle(SecondaryButtonStyle(height: 30))
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textControl)
                    .frame(width: 30, height: 30)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .background(Palette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Palette.inputRing, lineWidth: 0.5)
            )
            .accessibilityIdentifier("detail.more")
        }
    }
}

/// The last call this window made on the left, the app's standing promise on
/// the right.
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
