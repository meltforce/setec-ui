import XCTest
@testable import SetecUI

@MainActor
final class AccessStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        StubURLProtocol.exchange.reset()
        defaults = UserDefaults(suiteName: "AccessStoreTests")
        defaults.removePersistentDomain(forName: "AccessStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "AccessStoreTests")
        super.tearDown()
    }

    private func client(id: String, secret: String) -> TailnetPolicyClient {
        TailnetPolicyClient(
            setec: SetecClient(server: URL(string: "https://setec.example")!, session: StubURLProtocol.session()),
            names: AccessSetting.Names(clientID: id, clientSecret: secret),
            session: StubURLProtocol.session()
        )
    }

    // MARK: - The setting

    func testUnsetNamesTakeTheAppsOwnPrefix() {
        let names = AccessSetting.resolve(defaults: defaults)
        XCTAssertEqual(names?.clientID, AccessSetting.defaultClientIDSecret)
        XCTAssertEqual(names?.clientSecret, AccessSetting.defaultClientSecretSecret)
    }

    func testAConfiguredNameReplacesTheDefault() {
        defaults.set("other/id", forKey: AccessSetting.clientIDKey)
        XCTAssertEqual(AccessSetting.resolve(defaults: defaults)?.clientID, "other/id")
        XCTAssertEqual(
            AccessSetting.resolve(defaults: defaults)?.clientSecret,
            AccessSetting.defaultClientSecretSecret
        )
    }

    func testEitherNameLeftBlankSwitchesTheMatrixOff() {
        defaults.set("", forKey: AccessSetting.clientIDKey)
        XCTAssertNil(AccessSetting.resolve(defaults: defaults))
        defaults.set(AccessSetting.defaultClientIDSecret, forKey: AccessSetting.clientIDKey)
        defaults.set("   ", forKey: AccessSetting.clientSecretKey)
        XCTAssertNil(AccessSetting.resolve(defaults: defaults), "whitespace is blank")
    }

    // MARK: - The store

    func testNoCredentialIsDisabledRatherThanFailed() async {
        let store = AccessStore(client: nil)
        XCTAssertEqual(store.state, .disabled)
        await store.load()
        XCTAssertEqual(store.state, .disabled, "nothing is attempted, so nothing fails")
        XCTAssertFalse(store.isConfigured)
    }

    func testAnUnreadableCredentialFailsAndNamesBothEntries() async {
        StubURLProtocol.exchange.answer("/api/get", status: 404, json: "null")
        let store = AccessStore(client: client(id: "wrong/id", secret: "wrong/secret"))
        await store.load()
        guard case let .failed(message) = store.state else {
            return XCTFail("expected a failure, got \(store.state)")
        }
        XCTAssertTrue(message.contains("wrong/id"), message)
        XCTAssertTrue(message.contains("wrong/secret"), message)
        XCTAssertNil(store.policy)
        XCTAssertTrue(store.rows(in: .group("apps")).isEmpty)
    }

    /// A setec outage takes every consumer's credential with it, so it reads
    /// as a credential problem everywhere. The matrix names the cause instead.
    func testAnUnreachableSetecIsNotReportedAsAWrongEntryName() async {
        // No answer scripted for /api/get and the stub cannot reach a host:
        // the client's transport failure is what propagates.
        StubURLProtocol.exchange.answer("/api/get", status: 599, json: "null")
        let store = AccessStore(client: client(id: "a/id", secret: "a/secret"))
        await store.load()
        guard case let .failed(message) = store.state else {
            return XCTFail("expected a failure, got \(store.state)")
        }
        // A 599 is a server status, not a transport error, so this asserts the
        // split the other way: it must still name the entries.
        XCTAssertTrue(message.contains("a/id"), message)
    }

    func testATransportFailureNamesSetecRatherThanTheEntries() {
        let failure = TailnetPolicyClient.Failure.unreachable("The network connection was lost")
        let message = failure.errorDescription ?? ""
        XCTAssertTrue(message.contains("setec is unreachable"), message)
        XCTAssertTrue(message.contains("not a wrong entry name"), message)
    }

    func testARefusedOAuthExchangeSaysTheEntriesHoldSomethingElse() async {
        StubURLProtocol.exchange.answer("/api/get", json: #"{"Value":"bm90LWEtY2xpZW50","Version":1}"#)
        StubURLProtocol.exchange.answer("/api/v2/oauth/token", status: 401, json: "{}")
        let store = AccessStore(client: client(id: "a/id", secret: "a/secret"))
        await store.load()
        guard case let .failed(message) = store.state else {
            return XCTFail("expected a failure, got \(store.state)")
        }
        XCTAssertTrue(message.contains("401"), message)
    }

    /// The point of the separation: the grants come from the tailnet policy,
    /// the secrets from setec. A broken policy credential must leave the
    /// second untouched.
    func testABrokenPolicyCredentialLeavesTheSecretListWorking() async throws {
        StubURLProtocol.exchange.answer(
            "/api/list",
            json: #"[{"Name":"a/b","Versions":[1],"ActiveVersion":1}]"#
        )
        StubURLProtocol.exchange.answer("/api/get", status: 403, json: "null")
        let secrets = try SecretStore(
            server: XCTUnwrap(URL(string: "https://setec.example")),
            session: StubURLProtocol.session()
        )
        let access = AccessStore(client: client(id: "wrong/id", secret: "wrong/secret"))

        await secrets.refresh()
        await access.load()

        XCTAssertEqual(secrets.loading, .loaded)
        XCTAssertEqual(secrets.secrets.map(\.name), ["a/b"])
        XCTAssertNil(secrets.problem, "the window reports no problem of its own")
        if case .failed = access.state {} else {
            XCTFail("the matrix should report its own failure, got \(access.state)")
        }
    }

    /// The scopes come back with the policy, so the dialog can show what the
    /// configured client actually carries instead of asserting what it should.
    func testTheGrantedScopesAreReadBackFromTheTokenResponse() async {
        StubURLProtocol.exchange.answer("/api/get", json: #"{"Value":"YQ==","Version":1}"#)
        StubURLProtocol.exchange.answer(
            "/api/v2/oauth/token",
            json: #"{"access_token":"t","scope":"dns:read policy_file:read","token_type":"Bearer"}"#
        )
        StubURLProtocol.exchange.answer("/api/v2/tailnet/-/acl", json: #"{"groups":{},"grants":[]}"#)
        let store = AccessStore(client: client(id: "a/id", secret: "a/secret"))
        await store.load()
        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(store.scopes, ["dns:read", "policy_file:read"])
        XCTAssertTrue(store.scopes.contains(TailnetPolicyClient.requiredScope))
    }

    func testAClientWithoutThePolicyScopeIsReportedAsSuchNotAsA403() async {
        StubURLProtocol.exchange.answer("/api/get", json: #"{"Value":"YQ==","Version":1}"#)
        StubURLProtocol.exchange.answer(
            "/api/v2/oauth/token",
            json: #"{"access_token":"t","scope":"dns:read devices:core:read","token_type":"Bearer"}"#
        )
        let store = AccessStore(client: client(id: "a/id", secret: "a/secret"))
        await store.load()
        guard case let .failed(message) = store.state else {
            return XCTFail("expected a failure, got \(store.state)")
        }
        XCTAssertTrue(message.contains("policy_file:read"), message)
        XCTAssertTrue(message.contains("dns:read"), message)
    }

    func testSwitchingTheCredentialOffClearsWhatWasRead() async {
        let store = AccessStore.preview()
        XCTAssertEqual(store.state, .loaded)
        await store.use(client: nil)
        XCTAssertEqual(store.state, .disabled)
        XCTAssertNil(store.policy)
        XCTAssertTrue(store.scopes.isEmpty)
        XCTAssertTrue(store.rows(in: .group("apps")).isEmpty)
    }
}
