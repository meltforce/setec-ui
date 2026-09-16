import SwiftUI

/// The three-column shell: sidebar (sections), content (items), detail, plus a
/// trailing inspector. Replace the example feature; keep the shape.
struct RootView: View {
    @Environment(ItemStore.self) private var store
    @State private var section: ItemSection? = .inbox
    @State private var inspectorShown = true

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SectionList(selection: $section)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            ItemList(section: section ?? .inbox, selection: $store.selectedID)
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
        } detail: {
            ItemDetail(item: store.selected)
        }
        .inspector(isPresented: $inspectorShown) {
            ItemInspector(item: store.selected)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    inspectorShown.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .accessibilityIdentifier("toolbar.inspector")
            }
        }
        .navigationTitle(store.selected?.title ?? "Setec UI")
        .navigationSubtitle(subtitle)
        .focusedSceneValue(\.itemActions, ItemActions(
            newItem: { _ = store.add(title: "New Item") },
            next: { store.moveSelection(by: 1) },
            previous: { store.moveSelection(by: -1) },
            toggleInspector: { inspectorShown.toggle() }
        ))
    }

    private var subtitle: String {
        let count = store.items(in: section ?? .inbox).count
        return "\(count) item\(count == 1 ? "" : "s")"
    }
}

struct SectionList: View {
    @Binding var selection: ItemSection?

    var body: some View {
        List(ItemSection.allCases, selection: $selection) { section in
            Label(section.title, systemImage: section.symbol)
                .accessibilityIdentifier("sidebar.\(section.rawValue)")
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("sidebar.list")
    }
}

struct ItemList: View {
    @Environment(ItemStore.self) private var store
    let section: ItemSection
    @Binding var selection: String?

    var body: some View {
        let items = store.items(in: section)
        if items.isEmpty {
            ContentUnavailableView(
                "Nothing in \(section.title)",
                systemImage: section.symbol,
                description: Text("Items you add appear here.")
            )
        } else {
            List(items, selection: $selection) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                    Text(item.created, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("items.row.\(item.id)")
            }
            .accessibilityIdentifier("items.list")
        }
    }
}

struct ItemDetail: View {
    let item: Item?

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.title).font(.title)
                    Text(item.notes.isEmpty ? "No notes." : item.notes)
                        .foregroundStyle(item.notes.isEmpty ? .secondary : .primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .accessibilityIdentifier("detail.\(item.id)")
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "doc.text",
                description: Text("Select an item.")
            )
        }
    }
}

struct ItemInspector: View {
    @Environment(ItemStore.self) private var store
    let item: Item?

    var body: some View {
        if let item {
            Form {
                Section("Item") {
                    TextField("Title", text: binding(for: item, \.title))
                        .accessibilityIdentifier("inspector.title")
                    Picker("Section", selection: binding(for: item, \.section)) {
                        ForEach(ItemSection.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("inspector.section")
                    LabeledContent("Created") { Text(item.created, style: .date) }
                }
                Section("Notes") {
                    TextEditor(text: binding(for: item, \.notes))
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("inspector.notes")
                }
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView("No Item", systemImage: "info.circle")
        }
    }

    private func binding<T>(for item: Item, _ keyPath: WritableKeyPath<Item, T>) -> Binding<T> {
        Binding(
            get: { store.item(id: item.id)?[keyPath: keyPath] ?? item[keyPath: keyPath] },
            set: { newValue in store.update(id: item.id) { $0[keyPath: keyPath] = newValue } }
        )
    }
}
