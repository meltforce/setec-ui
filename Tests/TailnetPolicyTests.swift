import XCTest
@testable import SetecUI

final class TailnetPolicyTests: XCTestCase {
    private let json = """
    {
      "groups": {"group:admins": ["a@example.com", "b@example.com"]},
      "grants": [
        {
          "src": ["autogroup:admin"],
          "dst": ["tag:setec"],
          "app": {"tailscale.com/cap/secrets": [
            {"action": ["get", "info", "put", "activate", "delete", "list"], "secret": ["*"]}
          ]}
        },
        {
          "src": ["tag:servers", "group:admins"],
          "dst": ["tag:setec"],
          "app": {"tailscale.com/cap/secrets": [
            {"action": ["get"], "secret": ["apps/*"]},
            {"action": ["info"], "secret": ["infra/one"]}
          ]}
        },
        {
          "src": ["tag:other"],
          "dst": ["tag:setec"],
          "app": {"tailscale.com/cap/other": [{"action": ["x"]}]}
        }
      ]
    }
    """

    private func policy() throws -> TailnetPolicy {
        try TailnetPolicy(data: Data(json.utf8))
    }

    func testOnlySecretsGrantsAreParsed() throws {
        let policy = try policy()
        XCTAssertEqual(policy.rules.count, 3, "one entry per action/secret block, the other capability ignored")
        XCTAssertEqual(policy.groups["group:admins"]?.count, 2)
    }

    func testNoRuleGrantsCreateVersion() throws {
        let policy = try policy()
        let admin = try XCTUnwrap(policy.rules.first { $0.principals == ["autogroup:admin"] })
        XCTAssertFalse(admin.capabilities.contains(.createVersion))
        XCTAssertEqual(admin.capabilities.count, 5)
    }

    /// `list` is granted by the policy and is not one of the six columns. It
    /// is kept, because a matrix that omits a granted action states something
    /// false about the grant.
    func testAnActionWithoutAColumnIsKeptRatherThanDropped() throws {
        let policy = try policy()
        let admin = try XCTUnwrap(policy.rules.first { $0.principals == ["autogroup:admin"] })
        XCTAssertEqual(admin.otherActions, ["list"])
        let rows = try policy.access(in: .group("apps"), identity: nil)
        let adminRow = try XCTUnwrap(rows.first { $0.principal == "autogroup:admin" })
        XCTAssertEqual(adminRow.otherActions, ["list"])
        let ops = try XCTUnwrap(rows.first { $0.principal == "group:admins" })
        XCTAssertTrue(ops.otherActions.isEmpty)
    }

    func testPatternMatching() {
        XCTAssertTrue(SecretPattern(text: "apps/*").matches(name: "apps/a/b"))
        XCTAssertFalse(SecretPattern(text: "apps/*").matches(name: "appsfile"))
        XCTAssertTrue(SecretPattern(text: "infra/one").matches(name: "infra/one"))
        XCTAssertFalse(SecretPattern(text: "infra/one").matches(name: "infra/one-more"))
        XCTAssertTrue(SecretPattern(text: "*").overlaps(group: "anything"))
        XCTAssertTrue(SecretPattern(text: "apps/*").overlaps(group: "apps"))
        XCTAssertFalse(SecretPattern(text: "apps/*").overlaps(group: "infra"))
        XCTAssertTrue(SecretPattern(text: "infra/one").overlaps(group: "infra"))
    }

    func testMatrixMergesRulesPerPrincipal() throws {
        let rows = try policy().access(in: .group("apps"), identity: nil)
        XCTAssertEqual(rows.map(\.principal), ["autogroup:admin", "group:admins", "tag:servers"])
        let ops = try XCTUnwrap(rows.first { $0.principal == "group:admins" })
        XCTAssertEqual(ops.capabilities, [.get])
        XCTAssertEqual(ops.note, "2 members")
    }

    func testAScopeWithNoRuleYieldsNoRowsRatherThanAnEmptyGrant() throws {
        let rows = try policy().access(in: .name("nothing/here"), identity: nil)
        XCTAssertEqual(rows.map(\.principal), ["autogroup:admin"], "only the wildcard rule covers it")
    }

    func testTheCallersOwnRowIsMarkedAndSortedFirst() throws {
        let identity = TailnetIdentity(loginName: "b@example.com", nodeName: "mac.example.ts.net")
        let rows = try policy().access(in: .group("apps"), identity: identity)
        XCTAssertEqual(rows.first?.principal, "group:admins")
        XCTAssertTrue(rows.first?.isSelf == true)
    }
}
