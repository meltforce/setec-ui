import SwiftUI

/// Every stored version, with the active one marked. Activating a different
/// version is the rollback — the API has no rollback call and neither does
/// this app.
///
/// The design's "date · author" column and the digest are absent: `list`
/// returns version numbers only, and a plausible-looking author who did not
/// publish the version is worse than a missing column (`DECISIONS.md`).
struct VersionsSection: View {
    @Environment(SecretStore.self) private var store
    let secret: Secret

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Versions") {
                Text("Roll back by activating")
                    .font(Typeface.meta)
                    .foregroundStyle(Palette.textQuaternary)
            }
            VStack(spacing: 0) {
                ForEach(Array(secret.versions.reversed().enumerated()), id: \.element) { index, version in
                    if index > 0 {
                        Rectangle().fill(Palette.tableRow).frame(height: 0.5)
                    }
                    row(for: version)
                }
            }
            .panelSurface()
        }
    }

    private func row(for version: Int) -> some View {
        let isActive = version == secret.activeVersion
        let isLatest = version == secret.latestVersion
        return HStack(spacing: 12) {
            Text(verbatim: "v\(version)")
                .font(Typeface.monoVersion)
                .tabularDigits()
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 52, alignment: .leading)
                .accessibilityIdentifier("versions.row.\(version)")
            HStack(spacing: 6) {
                if isActive {
                    badge("active", text: Palette.activeBadgeText, fill: Palette.badgeFill)
                }
                if isLatest, !isActive {
                    badge("latest", text: Palette.textSecondary, fill: Palette.fill)
                }
            }
            .frame(width: 78, alignment: .leading)
            Spacer(minLength: 0)
            actions(for: version, isActive: isActive)
                .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isActive ? Palette.activeTableRow : .clear)
    }

    @ViewBuilder
    private func actions(for version: Int, isActive: Bool) -> some View {
        if isActive {
            Text("in use")
                .font(Typeface.meta)
                .foregroundStyle(Palette.textMeta)
        } else {
            HStack(spacing: 8) {
                Button("Activate") {
                    Task { _ = await store.activate(name: secret.name, version: version) }
                }
                .buttonStyle(SecondaryButtonStyle(height: 24))
                .accessibilityIdentifier("versions.activate.\(version)")
                Button("Delete") {
                    store.sheet = .deleteVersion(secret.name, version)
                }
                .buttonStyle(SecondaryButtonStyle(height: 24, destructive: true))
                .accessibilityIdentifier("versions.delete.\(version)")
            }
        }
    }

    private func badge(_ title: String, text: Color, fill: Color) -> some View {
        Text(verbatim: title)
            .font(Typeface.ui(11, .medium))
            .foregroundStyle(text)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
