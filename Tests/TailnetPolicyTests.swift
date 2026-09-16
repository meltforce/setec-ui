import XCTest
@testable import SetecUI

final class TailnetPolicyTests: XCTestCase {
    private let json = """
    {
      "groups": {"group:ops": ["a@example.com", "b@example.com"]},
      "grants": [
        {
          "src": ["autogroup:admin"],
          "dst": ["tag:setec"],
          "app": {"tailscale.com/cap/secrets": [
            {"action": ["get", "info", "put", "activate", "delete", "list"], "secret": ["*"]}
          ]}
        },
        {
          "src": ["tag:homelab", "group:ops"],
          "dst": ["tag:setec"],
          "app": {"tailscale.com/cap/secrets": [
            {"action": ["get"], "secret": ["docker/*"]},
            {"action": ["info"], "secret": ["homelab/one"]}
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
        XCTAssertEqual(policy.groups["group:ops"]?.count, 2)
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
        let rows = try policy.access(in: .group("docker"), identity: nil)
        let adminRow = try XCTUnwrap(rows.first { $0.principal == "autogroup:admin" })
        XCTAssertEqual(adminRow.otherActions, ["list"])
        let ops = try XCTUnwrap(rows.first { $0.principal == "group:ops" })
        XCTAssertTrue(ops.otherActions.isEmpty)
    }

    func testPatternMatching() {
        XCTAssertTrue(SecretPattern(text: "docker/*").matches(name: "docker/a/b"))
        XCTAssertFalse(SecretPattern(text: "docker/*").matches(name: "dockerfile"))
        XCTAssertTrue(SecretPattern(text: "homelab/one").matches(name: "homelab/one"))
        XCTAssertFalse(SecretPattern(text: "homelab/one").matches(name: "homelab/one-more"))
        XCTAssertTrue(SecretPattern(text: "*").overlaps(group: "anything"))
        XCTAssertTrue(SecretPattern(text: "docker/*").overlaps(group: "docker"))
        XCTAssertFalse(SecretPattern(text: "docker/*").overlaps(group: "homelab"))
        XCTAssertTrue(SecretPattern(text: "homelab/one").overlaps(group: "homelab"))
    }

    func testMatrixMergesRulesPerPrincipal() throws {
        let rows = try policy().access(in: .group("docker"), identity: nil)
        XCTAssertEqual(rows.map(\.principal), ["autogroup:admin", "group:ops", "tag:homelab"])
        let ops = try XCTUnwrap(rows.first { $0.principal == "group:ops" })
        XCTAssertEqual(ops.capabilities, [.get])
        XCTAssertEqual(ops.note, "2 members")
    }

    func testAScopeWithNoRuleYieldsNoRowsRatherThanAnEmptyGrant() throws {
        let rows = try policy().access(in: .name("nothing/here"), identity: nil)
        XCTAssertEqual(rows.map(\.principal), ["autogroup:admin"], "only the wildcard rule covers it")
    }

    func testTheCallersOwnRowIsMarkedAndSortedFirst() throws {
        let identity = TailnetIdentity(loginName: "b@example.com", nodeName: "mac.example.ts.net")
        let rows = try policy().access(in: .group("docker"), identity: identity)
        XCTAssertEqual(rows.first?.principal, "group:ops")
        XCTAssertTrue(rows.first?.isSelf == true)
    }
}
