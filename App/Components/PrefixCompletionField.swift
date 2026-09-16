import SwiftUI

/// The name field of the New secret sheet. It completes an existing prefix as
/// ghost text inside the field — a non-interactive overlay that repeats the
/// typed characters transparently and continues in grey, so the completion
/// lines up under the real caret. Tab or → accepts it.
///
/// The candidates are prefixes of existing names, one per path level. There is
/// nothing to create here: a group exists exactly as long as a secret carries
/// its prefix.
struct PrefixCompletionField: View {
    @Binding var text: String
    let candidates: [SecretName.Candidate]
    var ringColor: Color = Palette.inputRing
    var identifier = "sheet.name"
    var onSubmit: () -> Void = {}

    @FocusState private var focused: Bool

    private var completions: [SecretName.Candidate] {
        SecretName.completions(for: text, from: candidates)
    }

    private var ghost: String? {
        guard !text.isEmpty, let best = completions.first else { return nil }
        return String(best.prefix.dropFirst(text.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            field
            if focused, !completions.isEmpty {
                suggestions
            }
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                if let ghost {
                    HStack(spacing: 0) {
                        Text(verbatim: text).foregroundStyle(.clear)
                        Text(verbatim: ghost).foregroundStyle(Palette.ghostText)
                        Spacer(minLength: 0)
                    }
                    .font(Typeface.monoInput)
                    .allowsHitTesting(false)
                }
                TextField("", text: $text, prompt: Text(verbatim: "prod/service/key-name"))
                    .textFieldStyle(.plain)
                    .font(Typeface.monoInput)
                    .focused($focused)
                    .onSubmit(onSubmit)
                    .onKeyPress(.tab) { accept() }
                    .onKeyPress(.rightArrow) { accept() }
                    .accessibilityIdentifier(identifier)
            }
            if ghost != nil {
                Text("tab")
                    .font(Typeface.ui(10.5))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Palette.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .panelSurface(radius: 7, fill: Palette.panel, ring: ringColor)
    }

    private var suggestions: some View {
        VStack(spacing: 0) {
            ForEach(Array(completions.enumerated()), id: \.element.id) { index, candidate in
                if index > 0 {
                    Rectangle().fill(Palette.tableRow).frame(height: 0.5)
                }
                Button {
                    text = candidate.prefix
                } label: {
                    HStack {
                        Text(verbatim: candidate.prefix)
                            .font(Typeface.mono(12.5))
                            .foregroundStyle(Palette.textControl)
                        Spacer(minLength: 8)
                        Text(verbatim: "\(candidate.count)")
                            .font(Typeface.badge)
                            .tabularDigits()
                            .foregroundStyle(Palette.textMeta)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(identifier).option.\(index)")
            }
        }
        .panelSurface(radius: 8, fill: Palette.panel, ring: Palette.panelRing)
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
    }

    private func accept() -> KeyPress.Result {
        guard let best = completions.first, !text.isEmpty else { return .ignored }
        text = best.prefix
        return .handled
    }
}
