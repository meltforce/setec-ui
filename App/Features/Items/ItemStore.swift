import Foundation
import Observation

/// Example feature. Delete it together with `RootView`'s example columns when
/// the real feature exists; keep the shape (an `@Observable` store on the main
/// actor, value-type models, a `snapshot()` for the debug endpoint).
enum ItemSection: String, CaseIterable, Identifiable, Codable {
    case inbox, starred, archive

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .starred: "Starred"
        case .archive: "Archive"
        }
    }

    var symbol: String {
        switch self {
        case .inbox: "tray"
        case .starred: "star"
        case .archive: "archivebox"
        }
    }
}

struct Item: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var notes: String = ""
    var section: ItemSection = .inbox
    var created: Date = .now
}

@MainActor
@Observable
final class ItemStore {
    private(set) var items: [Item]
    var selectedID: String?

    init(items: [Item] = []) {
        self.items = items
        selectedID = items.first?.id
    }

    static func sample() -> ItemStore {
        ItemStore(items: [
            Item(title: "Welcome", notes: "This is the example feature. Replace it with yours."),
            Item(title: "Read the pattern skill", notes: "mac-ui-patterns has the layout rules."),
            Item(title: "Run make verify", section: .starred),
            Item(title: "Old note", section: .archive, created: .now.addingTimeInterval(-86400 * 30)),
        ])
    }

    var selected: Item? {
        item(id: selectedID)
    }

    func item(id: String?) -> Item? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    func items(in section: ItemSection) -> [Item] {
        items.filter { $0.section == section }
    }

    @discardableResult
    func add(title: String, section: ItemSection = .inbox) -> Item {
        let item = Item(title: title, section: section)
        items.insert(item, at: 0)
        selectedID = item.id
        Log.app.debug("added item \(item.id, privacy: .public)")
        return item
    }

    func select(id: String) {
        guard items.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    func moveSelection(by offset: Int) {
        guard let current = selected else {
            selectedID = items.first?.id
            return
        }
        let siblings = items(in: current.section)
        guard let index = siblings.firstIndex(where: { $0.id == current.id }) else { return }
        let next = max(0, min(siblings.count - 1, index + offset))
        selectedID = siblings[next].id
    }

    func update(id: String, _ change: (inout Item) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    /// What the debug endpoint returns for `state`. Keep it small and stable.
    func snapshot() -> [String: Any] {
        [
            "count": items.count,
            "selected": selectedID ?? NSNull(),
            "items": items.map { ["id": $0.id, "title": $0.title, "section": $0.section.rawValue] },
        ]
    }
}
