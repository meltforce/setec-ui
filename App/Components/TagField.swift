import SwiftUI

/// Multi-select type-ahead: removable chips plus an input with an inline result
/// list. Return adds the highlighted option and keeps focus for the next tag;
/// Backspace on an empty input removes the last chip; Esc discards the typed
/// text and leaves the field. See mac-ui-patterns/references/type-ahead.md.
struct TagField: View {
    let label: String
    let options: [String]
    @Binding var selection: [String]
    var identifier = "tags"
    /// Chips that cannot be removed (an inbox tag, a system label).
    var locked: Set<String> = []

    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool

    private var matches: [String] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let pool = options.filter { !selection.contains($0) }
        guard !needle.isEmpty else { return Array(pool.prefix(8)) }
        return Array(pool.filter { $0.lowercased().contains(needle) }.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(selection, id: \.self) { tag in
                    chip(tag)
                }
                TextField(label, text: $query, prompt: Text("Add \(label.lowercased())"))
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .accessibilityIdentifier("\(identifier).input")
                    .onChange(of: query) { _, _ in highlighted = 0 }
                    .onSubmit { add() }
                    .onExitCommand {
                        query = ""
                        focused = false
                    }
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    // Backspace inside a TextField: `.onKeyPress(.delete)` never fires
                    // and `press.key == .delete` is false; the press arrives as the
                    // DEL character (measured 2026-09-15, macOS 27.0).
                    .onKeyPress(phases: .down) { press in
                        guard press.characters == "\u{7F}", query.isEmpty else { return .ignored }
                        guard let last = selection.last(where: { !locked.contains($0) }) else { return .ignored }
                        selection.removeAll { $0 == last }
                        return .handled
                    }
            }
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
                                add()
                            }
                            .accessibilityIdentifier("\(identifier).option.\(index)")
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
            }
        }
    }

    /// Identifiers sit on the leaves: an identifier on the chip container would
    /// override the remove button's own (measured 2026-09-15).
    private func chip(_ tag: String) -> some View {
        HStack(spacing: 2) {
            Text(tag)
                .font(.callout)
                .accessibilityIdentifier("\(identifier).chip.\(tag.lowercased())")
            if !locked.contains(tag) {
                Button {
                    selection.removeAll { $0 == tag }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(tag)")
                .accessibilityIdentifier("\(identifier).remove.\(tag.lowercased())")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            locked.contains(tag) ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.15),
            in: Capsule()
        )
    }

    private func move(_ delta: Int) {
        guard !matches.isEmpty else { return }
        highlighted = max(0, min(matches.count - 1, highlighted + delta))
    }

    private func add() {
        guard matches.indices.contains(highlighted) else { return }
        selection.append(matches[highlighted])
        query = ""
        highlighted = 0
    }
}
