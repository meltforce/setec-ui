import SwiftUI

/// A key cap (⌘S, S, Esc) drawn as a small pill. Purely visual; the shortcut
/// itself lives in `Commands` or an `.onKeyPress`.
struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator))
            .accessibilityLabel(Text("Key \(text)"))
    }
}

/// A footer row of key caps with labels, for the two or three shortcuts a
/// screen lives on. Attach with `.safeAreaInset(edge: .bottom)`.
struct KeyHintBar: View {
    struct Hint: Identifiable {
        let key: String
        let label: String
        var id: String {
            key
        }
    }

    let hints: [Hint]

    init(_ hints: [(String, String)]) {
        self.hints = hints.map { Hint(key: $0.0, label: $0.1) }
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(hints) { hint in
                HStack(spacing: 5) {
                    KeyCap(text: hint.key)
                    Text(hint.label).font(.callout).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("hint.\(hint.key)")
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
