import XCTest
@testable import SetecUI

final class ReuseScanTests: XCTestCase {
    private func scan(_ pairs: [String: String]) -> ReuseScan {
        ReuseScan(
            digests: pairs.mapValues(ReuseScan.digest(of:)),
            failures: [:],
            finished: .now,
            attempted: pairs.count
        )
    }

    func testTheDigestIsStableAndSeparatesDifferentValues() {
        XCTAssertEqual(ReuseScan.digest(of: "hunter2"), ReuseScan.digest(of: "hunter2"))
        XCTAssertNotEqual(ReuseScan.digest(of: "hunter2"), ReuseScan.digest(of: "hunter3"))
        XCTAssertEqual(ReuseScan.digest(of: "").count, 64, "SHA-256 in hex")
    }

    func testOnlyNamesThatShareAValueAreReused() {
        let result = scan([
            "a/one": "same",
            "b/two": "same",
            "c/three": "different",
        ])
        XCTAssertEqual(result.reusedNames, ["a/one", "b/two"])
    }

    func testAValueHeldOnceIsNotReuse() {
        XCTAssertTrue(scan(["a/one": "x"]).reusedNames.isEmpty)
        XCTAssertTrue(scan([:]).reusedNames.isEmpty)
    }

    func testGroupsAreSortedBySizeAndCarryOnlyNames() {
        let result = scan([
            "a": "one", "b": "one", "c": "one",
            "d": "two", "e": "two",
            "f": "three",
        ])
        XCTAssertEqual(result.groups, [["a", "b", "c"], ["d", "e"]])
    }

    func testTheFilterMatchesNothingWithoutAScan() {
        let secret = Secret(name: "a/one", versions: [1], activeVersion: 1)
        XCTAssertFalse(SmartFilter.reusedValue.matches(secret))
        XCTAssertTrue(SmartFilter.reusedValue.matches(secret, reusedNames: ["a/one"]))
        XCTAssertTrue(SmartFilter.reusedValue.needsValues)
        XCTAssertFalse(SmartFilter.noRollback.needsValues)
    }
}
