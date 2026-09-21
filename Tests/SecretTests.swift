import XCTest
@testable import SetecUI

final class SecretTests: XCTestCase {
    func testNameIsSplitIntoPrefixAndLeaf() {
        let secret = Secret(name: "apps/photos/api-key", versions: [1, 2], activeVersion: 2)
        XCTAssertEqual(secret.prefix, "apps/photos/")
        XCTAssertEqual(secret.leaf, "api-key")
        XCTAssertEqual(secret.group, "apps")
    }

    func testAnUngroupedNameHasNoGroupAndNoPrefix() {
        let secret = Secret(name: "standalone", versions: [1], activeVersion: 1)
        XCTAssertNil(secret.group)
        XCTAssertEqual(secret.prefix, "")
        XCTAssertEqual(secret.leaf, "standalone")
    }

    func testVersionsAreSortedAndDerived() {
        let secret = Secret(name: "a/b", versions: [3, 1, 2], activeVersion: 2)
        XCTAssertEqual(secret.versions, [1, 2, 3])
        XCTAssertEqual(secret.latestVersion, 3)
        XCTAssertEqual(secret.nextVersion, 4)
        XCTAssertFalse(secret.latestIsActive)
        XCTAssertTrue(secret.hasRollback)
    }

    func testFiltersMatchWhatTheirTitlesClaim() {
        let single = Secret(name: "a/b", versions: [1], activeVersion: 1)
        let stale = Secret(name: "a/c", versions: [1, 2], activeVersion: 1)
        XCTAssertFalse(SmartFilter.multipleVersions.matches(single))
        XCTAssertTrue(SmartFilter.latestNotActive.matches(stale))
        XCTAssertTrue(SmartFilter.multipleVersions.matches(stale))
        XCTAssertFalse(SmartFilter.latestNotActive.matches(single))
    }
}
