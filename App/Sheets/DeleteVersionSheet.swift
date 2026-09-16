import SwiftUI

/// Deletes one non-active version. The whole-secret delete sits behind a typed
/// name; a single version does not, because what it removes is one stored
/// value while every other version and the name itself stay. It is a sheet
/// rather than an alert so that both destructive paths speak the same visual
/// language and both are reachable from a UI test.
struct DeleteVersionSheet: View {
    @Environment(SecretStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let name: String
    let version: Int

    @State private var submitting = false

    private var secret: Secret? {
        store.secrets.first { $0.name == name }
    }

    var body: some View {
        SheetChrome(
            width: 520,
            headerBackground: Palette.redHeaderFill,
            headerBorder: Palette.redRing
        ) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Delete version")
                        .font(Typeface.sheetTitle)
                        .foregroundStyle(Palette.redTitle)
                    VersionChip(version: version, emphasis: true)
                }
                Text(verbatim: name)
                    .font(Typeface.mono(12.5))
                    .foregroundStyle(Palette.redSubtitle)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("This removes")
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Circle()
                            .fill(Palette.redBullet)
                            .frame(width: 5, height: 5)
                        Text(verbatim: line)
                            .font(Typeface.control)
                            .foregroundStyle(Palette.textBody)
                            .lineSpacing(3)
                    }
                }
            }
            APIPreview(lines: ["POST /api/delete-version"], destructive: true)
        } footer: {
            SheetFooter(
                hint: "The active version is not affected",
                primaryTitle: "Delete version",
                enabled: !submitting,
                destructive: true,
                identifier: "deleteVersion",
                cancel: { dismiss() },
                submit: submit
            )
        }
    }

    private var lines: [String] {
        let active = secret?.activeVersion ?? 0
        let remaining = max((secret?.versions.count ?? 1) - 1, 0)
        return [
            "The stored value of v\(version). setec keeps no backup of it",
            "v\(version) is not reused — the next put takes the next free number",
            remaining == 1
                ? "One version remains, the active v\(active)"
                : "\(remaining) versions remain, including the active v\(active)",
        ]
    }

    private func submit() {
        guard !submitting else { return }
        submitting = true
        Task {
            let deleted = await store.deleteVersion(name: name, version: version)
            submitting = false
            if deleted {
                dismiss()
            }
        }
    }
}
