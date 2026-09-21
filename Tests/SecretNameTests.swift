import XCTest
@testable import SetecUI

final class SecretNameTests: XCTestCase {
    private let existing: Set<String> = [
        "apps/photos/api-key",
        "apps/photos/db-password",
        "infra/host-api-token",
    ]

    func testLeadingSlashesAreStrippedRatherThanRejected() {
        XCTAssertEqual(SecretName.normalize("//prod/db "), "prod/db")
    }

    func testVerdictCoversEveryHintState() {
        XCTAssertEqual(SecretName.verdict(for: "", existing: existing), .empty)
        XCTAssertEqual(SecretName.verdict(for: "Prod/DB", existing: existing), .invalid)
        XCTAssertEqual(SecretName.verdict(for: "prod/db-", existing: existing), .invalid)
        XCTAssertEqual(SecretName.verdict(for: "apps/photos/api-key", existing: existing), .collision)
        XCTAssertEqual(SecretName.verdict(for: "prod/db", existing: existing), .newGroup("prod"))
        XCTAssertEqual(SecretName.verdict(for: "apps/new-thing", existing: existing), .available)
    }

    func testOnlyAcceptableVerdictsEnableTheButton() {
        XCTAssertTrue(SecretName.Verdict.available.isAcceptable)
        XCTAssertTrue(SecretName.Verdict.newGroup("x").isAcceptable)
        XCTAssertFalse(SecretName.Verdict.collision.isAcceptable)
        XCTAssertFalse(SecretName.Verdict.invalid.isAcceptable)
        XCTAssertFalse(SecretName.Verdict.empty.isAcceptable)
    }

    func testPrefixesCarryOneEntryPerPathLevelWithCounts() {
        let candidates = SecretName.prefixes(in: existing)
        let counts = Dictionary(uniqueKeysWithValues: candidates.map { ($0.prefix, $0.count) })
        XCTAssertEqual(counts["apps/"], 2)
        XCTAssertEqual(counts["apps/photos/"], 2)
        XCTAssertEqual(counts["infra/"], 1)
        XCTAssertNil(counts["apps/photos/api-key"], "a full name is not a prefix")
    }

    func testCompletionsContinueTheTypedTextAndNothingElse() {
        let candidates = SecretName.prefixes(in: existing)
        XCTAssertEqual(SecretName.completions(for: "", from: candidates), [])
        XCTAssertEqual(SecretName.completions(for: "app", from: candidates).first?.prefix, "apps/")
        XCTAssertEqual(SecretName.completions(for: "apps/", from: candidates).first?.prefix, "apps/photos/")
        XCTAssertTrue(SecretName.completions(for: "zzz", from: candidates).isEmpty)
    }

    func testGroupsAreTheTopLevelPrefixes() {
        XCTAssertEqual(SecretName.groups(in: existing), ["apps", "infra"])
    }

    func testGeneratedValueHasTheRequestedLengthAndNoLookAlikes() {
        let value = SecretValueGenerator.generate()
        XCTAssertEqual(value.count, 32)
        for forbidden in "lI1oO0" {
            XCTAssertFalse(value.contains(forbidden), "generated value contains \(forbidden)")
        }
        XCTAssertNotEqual(value, SecretValueGenerator.generate())
    }
}
