import SwiftUI

/// Single-select type-ahead: a text field with an inline result list. Typing
/// filters (prefix matches first), ↓/↑ move the highlight, Return commits and
/// leaves the field, Esc discards the typed text and leaves the field, an
/// empty query plus Return clears the selection. See
/// mac-ui-patterns/references/type-ahead.md for the measured behaviour.
struct LookupField: View {
    let label: String
    let options: [String]
    @Binding var selection: String?
    var identifier = "lookup"
    var maxResults = 8

    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool

    private var matches: [String] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return Array(options.prefix(maxResults)) }
        let prefix = options.filter { $0.lowercased().hasPrefix(needle) }
        let contains = options.filter { !$0.lowercased().hasPrefix(needle) && $0.lowercased().contains(needle) }
        return Array((prefix + contains).prefix(maxResults))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(label, text: $query, prompt: Text(selection ?? "Type to search"))
                .focused($focused)
                .accessibilityIdentifier(identifier)
                .onChange(of: query) { _, _ in highlighted = 0 }
                .onSubmit { commit() }
                .onExitCommand { revert() }
                .onKeyPress(.downArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-1); return .handled }
                .onKeyPress(.tab) { commit(); return .ignored }
            if focused, !matches.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.element) { index, option in
                        Text(option)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(index == highlighted ? Color.accentColor.opacity(0.2) : .clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                highlighted = index
                                commit()
                            }
                            .accessibilityIdentifier("\(identifier).option.\(index)")
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
            }
        }
    }

    private func move(_ delta: Int) {
        guard !matches.isEmpty else { return }
        highlighted = max(0, min(matches.count - 1, highlighted + delta))
    }

    private func commit() {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            selection = nil
        } else if matches.indices.contains(highlighted) {
            selection = matches[highlighted]
        }
        query = ""
        focused = false
    }

    private func revert() {
        query = ""
        focused = false
    }
}
