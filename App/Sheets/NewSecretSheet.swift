import SwiftUI

/// Creates a secret. One field holds the whole name, because a namespace is
/// not a thing — the slashes are what the sidebar groups by, nothing more.
struct NewSecretSheet: View {
    @Environment(SecretStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var value = ""
    @State private var revealed = false
    @State private var activateNow = true
    @State private var submitting = false

    private var verdict: SecretName.Verdict {
        SecretName.verdict(for: name, existing: store.existingNames)
    }

    private var canSubmit: Bool {
        verdict.isAcceptable && !value.isEmpty && !submitting
    }

    var body: some View {
        SheetChrome {
            VStack(alignment: .leading, spacing: 3) {
                Text("New secret")
                    .font(Typeface.sheetTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text(verbatim: "On \(store.server?.host() ?? store.server?.absoluteString ?? "no server")")
                    .font(Typeface.control)
                    .foregroundStyle(Palette.textTertiary)
            }
        } content: {
            nameSection
            valueSection
            optionsSection
            APIPreview(lines: apiLines)
        } footer: {
            SheetFooter(
                hint: hint,
                primaryTitle: "Create secret",
                enabled: canSubmit,
                identifier: "newSecret",
                cancel: { dismiss() },
                submit: submit
            )
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Name")
            PrefixCompletionField(
                text: $name,
                candidates: store.prefixCandidates,
                ringColor: ringColor,
                identifier: "newSecret.name",
                onSubmit: {
                    if canSubmit {
                        submit()
                    }
                }
            )
            Text(verbatim: nameHint)
                .font(Typeface.meta)
                .foregroundStyle(nameHintColor)
                .accessibilityIdentifier("newSecret.nameHint")
            Text("Slashes group secrets in the sidebar.")
                .font(Typeface.meta)
                .foregroundStyle(Palette.textQuaternary)
            groupChips
        }
    }

    private var groupChips: some View {
        HStack(spacing: 6) {
            Text("Groups:")
                .font(Typeface.meta)
                .foregroundStyle(Palette.textQuaternary)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(store.topLevelGroups, id: \.self) { group in
                        let highlighted = name.hasPrefix("\(group)/")
                        Button {
                            name = "\(group)/"
                        } label: {
                            Text(verbatim: group)
                                .font(Typeface.mono(11.5))
                                .foregroundStyle(highlighted ? Palette.apiText : Palette.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(highlighted ? Palette.selectedRow : Palette.fill)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("newSecret.group.\(group)")
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Value") {
                HStack(spacing: 12) {
                    Button("Generate") { value = SecretValueGenerator.generate() }
                        .buttonStyle(LinkButtonStyle())
                        .accessibilityIdentifier("newSecret.generate")
                    Button(revealed ? "Hide" : "Reveal") { revealed.toggle() }
                        .buttonStyle(LinkButtonStyle())
                        .accessibilityIdentifier("newSecret.reveal")
                }
            }
            SecretValueEditor(text: $value, revealed: $revealed, identifier: "newSecret.value")
            HStack {
                Text(verbatim: "\(value.count) character\(value.count == 1 ? "" : "s")")
                Spacer(minLength: 12)
                Text("Encoded as base64 in transit · not written to disk")
            }
            .font(Typeface.meta)
            .foregroundStyle(Palette.textQuaternary)
        }
    }

    private var optionsSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activate immediately")
                    .font(Typeface.controlEmphasis)
                    .foregroundStyle(Palette.textControl)
                Text(verbatim: activateNow
                    ? "Consumers pick up this value on their next fetch."
                    : "Stored as an inactive version until you activate it.")
                    .font(Typeface.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer(minLength: 0)
            Toggle("Activate immediately", isOn: $activateNow)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityIdentifier("newSecret.activate")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .panelSurface()
    }

    // MARK: - Copy

    private var apiLines: [String] {
        var lines = ["POST /api/put"]
        if activateNow {
            lines.append("→ POST /api/activate")
        }
        return lines
    }

    private var ringColor: Color {
        switch verdict {
        case .collision, .invalid: Palette.collisionRing
        case .empty: Palette.inputRing
        case .available, .newGroup: Palette.selectionRing
        }
    }

    private var nameHint: String {
        switch verdict {
        case .empty: "Grouping is just part of the name — a new prefix creates a new group"
        case .invalid: "Lowercase, digits, . _ - and / only"
        case .collision: "Already exists — use New version instead"
        case let .newGroup(group): "Creates new group \(group)/"
        case .available: "Name is available"
        }
    }

    private var nameHintColor: Color {
        switch verdict {
        case .empty: Palette.textQuaternary
        case .invalid, .collision: Palette.destructiveLabel
        case .newGroup: Palette.apiText
        case .available: Palette.availableName
        }
    }

    private var hint: String {
        if value.isEmpty {
            return "Add a value"
        }
        if !verdict.isAcceptable {
            return "Enter a valid name"
        }
        return "⌘↩ to create"
    }

    private func submit() {
        guard canSubmit else { return }
        submitting = true
        let target = SecretName.normalize(name)
        Task {
            let created = await store.createSecret(name: target, value: value, activate: activateNow)
            submitting = false
            if created {
                dismiss()
            }
        }
    }
}
