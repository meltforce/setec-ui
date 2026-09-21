import XCTest
@testable import SetecUI

@MainActor
final class SecretStoreTests: XCTestCase {
    private func store() -> SecretStore {
        SecretStore.preview()
    }

    func testGroupCountsAreDerivedFromTheNames() {
        let counts = Dictionary(uniqueKeysWithValues: store().groupCounts.map { ($0.group, $0.count) })
        XCTAssertEqual(counts["apps"], 2)
        XCTAssertEqual(counts["infra"], 2)
        XCTAssertEqual(counts["ops"], 1)
        XCTAssertNil(counts["standalone-token"], "a name without a slash forms no group")
    }

    func testUngroupedSecretsAreCountedSeparately() {
        XCTAssertEqual(store().ungroupedCount, 1)
    }

    func testSelectingAGroupFiltersTheList() {
        let store = store()
        store.scope = .group("apps")
        XCTAssertEqual(store.visible.map(\.name), ["apps/photos/api-key", "apps/photos/db-password"])
        XCTAssertEqual(store.listTitle, "apps/")
    }

    func testAFilterReplacesTheGroupSelection() {
        let store = store()
        store.scope = .group("apps")
        store.scope = .filter(.latestNotActive)
        XCTAssertEqual(store.visible.map(\.name), ["infra/git-api-token"])
        XCTAssertEqual(store.count(for: .multipleVersions), 4)
    }

    func testSearchOverridesScopeAndSearchesEverySecret() {
        let store = store()
        store.scope = .group("ops")
        store.query = "photos"
        XCTAssertEqual(store.visible.count, 2)
        XCTAssertEqual(store.listTitle, "Search: photos")
    }

    func testChangingTheScopeClearsTheSearch() {
        let store = store()
        store.query = "photos"
        store.scope = .group("infra")
        XCTAssertEqual(store.query, "")
    }

    func testSortOrderAppliesToTheVisibleList() {
        let store = store()
        store.sort = .nameDescending
        XCTAssertEqual(store.visible.first?.name, "standalone-token")
        store.sort = .versionCount
        XCTAssertEqual(store.visible.first?.versions.count, 3)
    }

    func testSelectingASecretResetsTheRevealState() {
        let store = store()
        store.selectedName = "ops/grafana-admin"
        XCTAssertNil(store.revealed)
        XCTAssertEqual(store.lastCall, "Selected ops/grafana-admin")
    }

    func testTheSnapshotCarriesNoValue() {
        let store = store()
        store.selectedName = "ops/grafana-admin"
        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot["count"] as? Int, 6)
        XCTAssertEqual(snapshot["selected"] as? String, "ops/grafana-admin")
        XCTAssertEqual(snapshot["revealed"] as? Bool, false)
        XCTAssertNil(snapshot["value"])
    }

    func testAutocompleteCandidatesComeFromTheLoadedNames() {
        let prefixes = store().prefixCandidates.map(\.prefix)
        XCTAssertTrue(prefixes.contains("apps/photos/"))
        XCTAssertEqual(store().topLevelGroups, ["apps", "infra", "ops"])
    }
}
