import SwiftUI

/// Copies a secret to another name, or moves it there. setec has no rename, so
/// both are a copy of the active value; a move then deletes the source, and
/// only after the copy has read back correctly (`SecretStore.copySecret`).
///
/// The name field starts on the source name, because the usual edit is the
/// group in front of the leaf: `juno/todoist-token` becomes
/// `docker/gate-jobs/todoist-token`. The group chips keep the leaf for the
/// same reason.
struct TransferSecretSheet: View {
    @Environment(SecretStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let name: String
    let removingSource: Bool

    @State private var target: String
    @State private var submitting = false

    init(name: String, removingSource: Bool) {
        self.name = name
        self.removingSource = removingSource
        _target = State(initialValue: name)
    }

    private var secret: Secret? {
        store.secrets.first { $0.name == name }
    }

    private var leaf: String {
        secret?.leaf ?? name
    }

    private var verdict: SecretName.Verdict {
        SecretName.verdict(for: target, existing: store.existingNames)
    }

    private var isSource: Bool {
        SecretName.normalize(target) == name
    }

    private var canSubmit: Bool {
        verdict.isAcceptable && !submitting
    }

    private var identifier: String {
        removingSource ? "moveSecret" : "copySecret"
    }

    var body: some View {
        SheetChrome(
            headerBackground: removingSource ? Palette.redHeaderFill : .clear,
            headerBorder: removingSource ? Palette.redRing : Palette.sectionBorder
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text(removingSource ? "Move secret" : "Copy secret")
                    .font(Typeface.sheetTitle)
                    .foregroundStyle(removingSource ? Palette.redTitle : Palette.textPrimary)
                Text(verbatim: name)
                    .font(Typeface.mono(12.5))
                    .foregroundStyle(removingSource ? Palette.redSubtitle : Palette.textTertiary)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("\(identifier).source")
            }
        } content: {
            nameSection
            consequences
            APIPreview(lines: apiLines, destructive: removingSource)
        } footer: {
            SheetFooter(
                hint: hint,
                primaryTitle: removingSource ? "Move secret" : "Copy secret",
                enabled: canSubmit,
                destructive: removingSource,
                identifier: identifier,
                cancel: { dismiss() },
                submit: submit
            )
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("New name")
            PrefixCompletionField(
                text: $target,
                candidates: store.prefixCandidates,
                ringColor: ringColor,
                identifier: "\(identifier).name",
                onSubmit: {
                    if canSubmit {
                        submit()
                    }
                }
            )
            Text(verbatim: nameHint)
                .font(Typeface.meta)
                .foregroundStyle(nameHintColor)
                .accessibilityIdentifier("\(identifier).nameHint")
            groupChips
        }
    }

    /// A chip puts the leaf under that group, so one press gives a complete
    /// name rather than a bare prefix.
    private var groupChips: some View {
        HStack(spacing: 6) {
            Text("Groups:")
                .font(Typeface.meta)
                .foregroundStyle(Palette.textQuaternary)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(store.topLevelGroups, id: \.self) { group in
                        let highlighted = target.hasPrefix("\(group)/")
                        Button {
                            target = "\(group)/\(leaf)"
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
                        .accessibilityIdentifier("\(identifier).group.\(group)")
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }

    private var consequences: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("This does")
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Circle()
                        .fill(removingSource ? Palette.redBullet : Palette.textQuaternary)
                        .frame(width: 5, height: 5)
                    Text(verbatim: line)
                        .font(Typeface.control)
                        .foregroundStyle(Palette.textBody)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var lines: [String] {
        let active = secret?.activeVersion ?? 0
        let others = (secret?.versions ?? []).filter { $0 != active }.map { "v\($0)" }
        var result = ["The active value, v\(active), becomes the one active version of the new name"]
        if !others.isEmpty {
            let list = others.joined(separator: ", ")
            result.append("\(list) of \(name) \(others.count == 1 ? "is" : "are") not copied")
        }
        if removingSource {
            result.append("\(name) is deleted with all its versions once the copy reads back correctly")
            result.append("Any client still fetching \(name) starts failing immediately")
        } else {
            result.append("\(name) stays as it is; the two names change independently from here on")
        }
        return result
    }

    // MARK: - Copy

    /// One line per request, because the preview counts its lines as
    /// requests.
    private var apiLines: [String] {
        var result = [
            "POST /api/get",
            "→ POST /api/put",
            "→ POST /api/activate",
            "→ POST /api/get, reading the copy back",
        ]
        if removingSource {
            result.append("→ POST /api/delete")
        }
        return result
    }

    private var ringColor: Color {
        switch verdict {
        case .collision where isSource: Palette.inputRing
        case .collision, .invalid: Palette.collisionRing
        case .empty: Palette.inputRing
        case .available, .newGroup: Palette.selectionRing
        }
    }

    private var nameHint: String {
        switch verdict {
        case .empty: "Enter the name to \(removingSource ? "move" : "copy") to"
        case .invalid: "Lowercase, digits, . _ - and / only"
        case .collision where isSource: "This is the current name — change the group or the name"
        case .collision: "Already exists — choose a free name"
        case let .newGroup(group): "Creates new group \(group)/"
        case .available: "Name is available"
        }
    }

    private var nameHintColor: Color {
        switch verdict {
        case .empty: Palette.textQuaternary
        case .collision where isSource: Palette.textQuaternary
        case .invalid, .collision: Palette.destructiveLabel
        case .newGroup: Palette.apiText
        case .available: Palette.availableName
        }
    }

    private var hint: String {
        verdict.isAcceptable ? "⌘↩ to \(removingSource ? "move" : "copy")" : "Enter a free name"
    }

    private func submit() {
        guard canSubmit else { return }
        submitting = true
        let destination = SecretName.normalize(target)
        Task {
            let done = await store.copySecret(name: name, to: destination, removingSource: removingSource)
            submitting = false
            if done {
                dismiss()
            }
        }
    }
}
