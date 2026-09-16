import SwiftUI

/// Deletes every version of a secret. The typed-name confirmation is what
/// replaces the CLI's `confirm-token`, which the upstream source calls a
/// request digest and states is not a security feature.
struct DeleteSecretSheet: View {
    @Environment(SecretStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let name: String

    @State private var typed = ""
    @State private var copied = false
    @State private var submitting = false

    private var secret: Secret? {
        store.secrets.first { $0.name == name }
    }

    private var matches: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines) == name
    }

    var body: some View {
        SheetChrome(
            width: 560,
            headerBackground: Palette.redHeaderFill,
            headerBorder: Palette.redRing
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Delete secret")
                    .font(Typeface.sheetTitle)
                    .foregroundStyle(Palette.redTitle)
                Text("This cannot be undone. setec keeps no backup of deleted values.")
                    .font(Typeface.control)
                    .foregroundStyle(Palette.redSubtitle)
            }
        } content: {
            consequences
            confirmation
            APIPreview(lines: ["POST /api/delete"], destructive: true)
        } footer: {
            SheetFooter(
                hint: "To remove a single version instead, use the version list",
                primaryTitle: "Delete secret",
                enabled: matches && !submitting,
                destructive: true,
                identifier: "deleteSecret",
                cancel: { dismiss() },
                submit: submit
            )
        }
    }

    private var consequences: some View {
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
    }

    private var lines: [String] {
        let count = secret?.versions.count ?? 0
        let active = secret?.activeVersion ?? 0
        return [
            count == 1
                ? "The one stored version, v\(active), which is the active one"
                : "All \(count) stored versions, including the active v\(active)",
            "Any client still fetching this name starts failing immediately",
            "The name becomes free again — deleted values cannot be restored",
        ]
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To confirm, type the secret name")
                .font(Typeface.ui(12, .semibold))
                .foregroundStyle(Palette.textField)
            HStack(spacing: 10) {
                Text(verbatim: name)
                    .font(Typeface.monoInput)
                    .foregroundStyle(Palette.textControl)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Button(copied ? "Copied" : "Copy") { copyName() }
                    .buttonStyle(SecondaryButtonStyle(height: 24))
                    .accessibilityIdentifier("deleteSecret.copyName")
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .panelSurface(radius: 8, fill: Palette.fill, ring: Palette.subtleRing)

            TextField("", text: $typed, prompt: Text(verbatim: name))
                .textFieldStyle(.plain)
                .font(Typeface.monoInput)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .panelSurface(radius: 8, fill: Palette.panel, ring: ringColor)
                .onSubmit {
                    if matches {
                        submit()
                    }
                }
                .accessibilityIdentifier("deleteSecret.confirmName")

            Text(verbatim: hint)
                .font(Typeface.meta)
                .foregroundStyle(matches ? Palette.matchConfirmed : Palette.textQuaternary)
                .accessibilityIdentifier("deleteSecret.hint")
        }
    }

    private var ringColor: Color {
        if matches {
            return Palette.redInputRing
        }
        return typed.isEmpty ? Palette.inputRing : Palette.subtleRing
    }

    private var hint: String {
        if matches {
            return "Name matches"
        }
        return typed.isEmpty ? "Type the full name to enable deletion" : "Does not match yet"
    }

    private func copyName() {
        SecretPasteboard.copyPlain(name)
        copied = true
        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            copied = false
        }
    }

    private func submit() {
        guard matches, !submitting else { return }
        submitting = true
        Task {
            let deleted = await store.deleteSecret(name: name)
            submitting = false
            if deleted {
                dismiss()
            }
        }
    }
}
