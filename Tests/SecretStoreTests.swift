import XCTest
@testable import SetecUI

@MainActor
final class SecretStoreTests: XCTestCase {
    private func store() -> SecretStore {
        SecretStore.preview()
    }

    func testGroupCountsAreDerivedFromTheNames() {
        let counts = Dictionary(uniqueKeysWithValues: store().groupCounts.map { ($0.group, $0.count) })
        XCTAssertEqual(counts["docker"], 2)
        XCTAssertEqual(counts["homelab"], 2)
        XCTAssertEqual(counts["juno"], 1)
        XCTAssertNil(counts["standalone-token"], "a name without a slash forms no group")
    }

    func testUngroupedSecretsAreCountedSeparately() {
        XCTAssertEqual(store().ungroupedCount, 1)
    }

    func testSelectingAGroupFiltersTheList() {
        let store = store()
        store.scope = .group("docker")
        XCTAssertEqual(store.visible.map(\.name), ["docker/immich/api-key", "docker/immich/db-password"])
        XCTAssertEqual(store.listTitle, "docker/")
    }

    func testAFilterReplacesTheGroupSelection() {
        let store = store()
        store.scope = .group("docker")
        store.scope = .filter(.latestNotActive)
        XCTAssertEqual(store.visible.map(\.name), ["homelab/forgejo-api-token"])
        XCTAssertEqual(store.count(for: .noRollback), 2)
    }

    func testSearchOverridesScopeAndSearchesEverySecret() {
        let store = store()
        store.scope = .group("juno")
        store.query = "immich"
        XCTAssertEqual(store.visible.count, 2)
        XCTAssertEqual(store.listTitle, "Search: immich")
    }

    func testChangingTheScopeClearsTheSearch() {
        let store = store()
        store.query = "immich"
        store.scope = .group("homelab")
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
        store.selectedName = "juno/grafana-admin"
        XCTAssertNil(store.revealed)
        XCTAssertEqual(store.lastCall, "Selected juno/grafana-admin")
    }

    func testTheSnapshotCarriesNoValue() {
        let store = store()
        store.selectedName = "juno/grafana-admin"
        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot["count"] as? Int, 6)
        XCTAssertEqual(snapshot["selected"] as? String, "juno/grafana-admin")
        XCTAssertEqual(snapshot["revealed"] as? Bool, false)
        XCTAssertNil(snapshot["value"])
    }

    func testAutocompleteCandidatesComeFromTheLoadedNames() {
        let prefixes = store().prefixCandidates.map(\.prefix)
        XCTAssertTrue(prefixes.contains("docker/immich/"))
        XCTAssertEqual(store().topLevelGroups, ["docker", "homelab", "juno"])
    }
}
