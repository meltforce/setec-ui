import XCTest
@testable import SetecUI

@MainActor
final class ItemStoreTests: XCTestCase {
    func testAddSelectsTheNewItem() {
        let store = ItemStore()
        let item = store.add(title: "One")
        XCTAssertEqual(store.selectedID, item.id)
        XCTAssertEqual(store.items(in: .inbox).count, 1)
    }

    func testMoveSelectionStaysInsideTheSection() {
        let store = ItemStore.sample()
        store.select(id: store.items(in: .inbox)[0].id)
        store.moveSelection(by: -1)
        XCTAssertEqual(store.selectedID, store.items(in: .inbox)[0].id)
        store.moveSelection(by: 10)
        XCTAssertEqual(store.selectedID, store.items(in: .inbox).last?.id)
    }

    func testSnapshotListsEveryItem() {
        let store = ItemStore.sample()
        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot["count"] as? Int, store.items.count)
    }
}
