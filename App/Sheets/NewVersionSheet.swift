import SwiftUI

/// Appends a version to an existing secret. The name is fixed; what the sheet
/// decides is the value and whether the new version becomes the active one.
struct NewVersionSheet: View {
    @Environment(SecretStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let name: String

    @State private var value = ""
    @State private var revealed = false
    @State private var activateOnCreate = true
    @State private var submitting = false
    @State private var loadingCurrent = false
    @State private var currentValue: String?
    @State private var currentLength: Int?

    private var secret: Secret? {
        store.secrets.first { $0.name == name }
    }

    private var targetVersion: Int {
        (secret?.nextVersion) ?? 1
    }

    private var isDuplicate: Bool {
        guard let currentValue, !value.isEmpty else { return false }
        return currentValue == value
    }

    private var canSubmit: Bool {
        !value.isEmpty && !submitting
    }

    var body: some View {
        SheetChrome {
            header
        } content: {
            valueSection
            if isDuplicate, let secret {
                duplicateWarning(activeVersion: secret.activeVersion)
            }
            optionsSection
            APIPreview(lines: apiLines)
        } footer: {
            SheetFooter(
                hint: hint,
                primaryTitle: activateOnCreate ? "Create and activate" : "Create version",
                enabled: canSubmit,
                identifier: "newVersion",
                cancel: { dismiss() },
                submit: submit
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text("New version")
                    .font(Typeface.sheetTitle)
                    .foregroundStyle(Palette.textPrimary)
                VersionChip(version: targetVersion, emphasis: true)
                Text(verbatim: name)
                    .font(Typeface.mono(12.5))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Text(verbatim: subtitle)
                .font(Typeface.control)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var subtitle: String {
        guard let secret else { return "The secret is no longer in the list." }
        return "Current active version is v\(secret.activeVersion). Versions carry no timestamp in setec."
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Value") {
                HStack(spacing: 12) {
                    Button("Generate") {
                        value = SecretValueGenerator.generate(length: max(32, currentLength ?? 32))
                    }
                    .buttonStyle(LinkButtonStyle())
                    .accessibilityIdentifier("newVersion.generate")
                    Button(loadingCurrent ? "Loading …" : "Start from current") { loadCurrent() }
                        .buttonStyle(LinkButtonStyle())
                        .disabled(loadingCurrent)
                        .accessibilityIdentifier("newVersion.startFromCurrent")
                    Button(revealed ? "Hide" : "Reveal") { revealed.toggle() }
                        .buttonStyle(LinkButtonStyle())
                        .accessibilityIdentifier("newVersion.reveal")
                }
            }
            SecretValueEditor(text: $value, revealed: $revealed, identifier: "newVersion.value")
            HStack {
                Text(verbatim: comparison)
                Spacer(minLength: 12)
                Text("Encoded as base64 in transit · not written to disk")
            }
            .font(Typeface.meta)
            .foregroundStyle(Palette.textQuaternary)
        }
    }

    private var comparison: String {
        guard let currentLength else {
            return value.isEmpty
                ? "Empty · the current value has not been loaded"
                : "\(value.count) character\(value.count == 1 ? "" : "s")"
        }
        return value.isEmpty
            ? "Empty · current value is \(currentLength) characters"
            : "\(value.count) characters · was \(currentLength)"
    }

    private func duplicateWarning(activeVersion: Int) -> some View {
        HStack(spacing: 9) {
            Circle().fill(Palette.rotationDue).frame(width: 7, height: 7)
            Text(verbatim: "Identical to v\(activeVersion) — this would create a duplicate version")
                .font(Typeface.meta)
                .foregroundStyle(Palette.warningText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .panelSurface(radius: 8, fill: Palette.warningFill, ring: Palette.warningRing)
        .accessibilityIdentifier("newVersion.duplicate")
    }

    private var optionsSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activate on create")
                    .font(Typeface.controlEmphasis)
                    .foregroundStyle(Palette.textControl)
                Text(verbatim: explanation)
                    .font(Typeface.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer(minLength: 0)
            Toggle("Activate on create", isOn: $activateOnCreate)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityIdentifier("newVersion.activate")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .panelSurface()
    }

    private var explanation: String {
        let active = secret?.activeVersion ?? 0
        return activateOnCreate
            ? "v\(targetVersion) becomes active — consumers pick it up on their next fetch."
            : "Stored alongside v\(active), which stays active until you switch."
    }

    private var apiLines: [String] {
        var lines = ["POST /api/put"]
        if activateOnCreate {
            lines.append("→ POST /api/activate")
        }
        return lines
    }

    private var hint: String {
        if value.isEmpty {
            return "Add a value"
        }
        return activateOnCreate
            ? "Previous version stays available for rollback"
            : "Activate later from the version list"
    }

    private func loadCurrent() {
        loadingCurrent = true
        Task {
            if let loaded = await store.currentValue() {
                value = loaded
                currentValue = loaded
                currentLength = loaded.count
            }
            loadingCurrent = false
        }
    }

    private func submit() {
        guard canSubmit else { return }
        submitting = true
        Task {
            let created = await store.createVersion(name: name, value: value, activate: activateOnCreate)
            submitting = false
            if created {
                dismiss()
            }
        }
    }
}
