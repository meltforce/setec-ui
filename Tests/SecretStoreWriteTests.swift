import XCTest
@testable import SetecUI

/// The write paths against the scripted `URLProtocol`. What they assert is the
/// call sequence: `put` and `activate` are two calls, which is what the
/// sheets' API preview tells the user, and `activate` alone is the rollback.
@MainActor
final class SecretStoreWriteTests: XCTestCase {
    private var store: SecretStore!

    override func setUp() {
        super.setUp()
        StubURLProtocol.exchange.reset()
        store = SecretStore(server: URL(string: "https://setec.example")!, session: StubURLProtocol.session())
    }

    private func answerList(_ json: String = #"[{"Name":"a/b","Versions":[1],"ActiveVersion":1}]"#) {
        StubURLProtocol.exchange.answer("/api/list", json: json)
    }

    func testRefreshLoadsTheListAndSortsIt() async {
        answerList(#"""
        [{"Name":"b/x","Versions":[1],"ActiveVersion":1},{"Name":"a/x","Versions":[1,2],"ActiveVersion":2}]
        """#)
        await store.refresh()
        XCTAssertEqual(store.loading, .loaded)
        XCTAssertEqual(store.secrets.map(\.name), ["a/x", "b/x"])
        XCTAssertNotNil(store.lastSynced)
    }

    func testAFailedListIsReportedRatherThanShownAsEmpty() async {
        StubURLProtocol.exchange.answer("/api/list", status: 500, json: "null")
        await store.refresh()
        guard case let .failed(message) = store.loading else {
            return XCTFail("expected a failure, got \(store.loading)")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(store.secrets.isEmpty)
    }

    func testCreatingWithActivationIssuesPutThenActivate() async {
        answerList()
        StubURLProtocol.exchange.answer("/api/put", json: "7")
        StubURLProtocol.exchange.answer("/api/activate", json: "null")
        let created = await store.createSecret(name: "a/new", value: "s3cret", activate: true)
        XCTAssertTrue(created)
        let calls = StubURLProtocol.exchange.requests.map(\.path)
        XCTAssertEqual(calls.prefix(2).map(\.self), ["/api/put", "/api/activate"])
        let activate = StubURLProtocol.exchange.lastBody(to: "/api/activate")
        XCTAssertEqual(activate?["Version"] as? Int, 7, "the version the server assigned, not a guess")
        XCTAssertEqual(store.selectedName, "a/new")
    }

    func testCreatingWithoutActivationIssuesPutAlone() async {
        answerList()
        StubURLProtocol.exchange.answer("/api/put", json: "2")
        let created = await store.createSecret(name: "a/b", value: "s3cret", activate: false)
        XCTAssertTrue(created)
        XCTAssertFalse(StubURLProtocol.exchange.requests.contains { $0.path == "/api/activate" })
    }

    func testRollbackIsAnActivateCall() async {
        answerList()
        StubURLProtocol.exchange.answer("/api/activate", json: "null")
        let done = await store.activate(name: "a/b", version: 1)
        XCTAssertTrue(done)
        XCTAssertEqual(store.lastCall, #"POST /api/activate {"Name":"a/b","Version":1}"#)
    }

    func testDeletingTheSelectedSecretClearsTheSelection() async {
        answerList()
        StubURLProtocol.exchange.answer("/api/delete", json: "null")
        await store.refresh()
        store.selectedName = "a/b"
        StubURLProtocol.exchange.answer("/api/list", json: "[]")
        let deleted = await store.deleteSecret(name: "a/b")
        XCTAssertTrue(deleted)
        XCTAssertNil(store.selectedName)
    }

    /// The status code is not the confirmation: a server that answers 200 and
    /// keeps the secret must not be reported as a successful deletion.
    func testADeleteThatChangesNothingIsReportedAsAFailure() async {
        answerList()
        StubURLProtocol.exchange.answer("/api/delete", json: "null")
        await store.refresh()
        store.selectedName = "a/b"
        // The list keeps answering with the secret, as a refusing server would.
        let deleted = await store.deleteSecret(name: "a/b")
        XCTAssertFalse(deleted, "accepted by the server, but nothing was removed")
        XCTAssertEqual(
            store.problem,
            "The server accepted the delete, but a/b is still in the list. Nothing was removed."
        )
        XCTAssertEqual(store.secrets.map(\.name), ["a/b"])
    }

    func testAVersionDeleteThatChangesNothingIsReportedAsAFailure() async {
        answerList(#"[{"Name":"a/b","Versions":[1,2],"ActiveVersion":1}]"#)
        StubURLProtocol.exchange.answer("/api/delete-version", json: "null")
        await store.refresh()
        let deleted = await store.deleteVersion(name: "a/b", version: 2)
        XCTAssertFalse(deleted)
        XCTAssertEqual(store.problem, "The server accepted the delete, but v2 of a/b is still in the list.")
    }

    func testDeletingAVersionKeepsTheSecret() async {
        answerList(#"[{"Name":"a/b","Versions":[1,2],"ActiveVersion":1}]"#)
        StubURLProtocol.exchange.answer("/api/delete-version", json: "null")
        await store.refresh()
        // The refresh inside the call sees the version gone, as a server that
        // honoured the request would report it.
        answerList(#"[{"Name":"a/b","Versions":[1],"ActiveVersion":1}]"#)
        let deleted = await store.deleteVersion(name: "a/b", version: 2)
        XCTAssertTrue(deleted)
        let body = StubURLProtocol.exchange.lastBody(to: "/api/delete-version")
        XCTAssertEqual(body?["Version"] as? Int, 2)
    }

    func testAForbiddenWriteIsReportedAndChangesNothing() async {
        answerList()
        StubURLProtocol.exchange.answer("/api/put", status: 403, json: "null")
        await store.refresh()
        let created = await store.createSecret(name: "a/new", value: "s3cret", activate: true)
        XCTAssertFalse(created)
        XCTAssertEqual(store.problem, "Not permitted for a/new")
        XCTAssertEqual(store.secrets.map(\.name), ["a/b"])
    }

    func testRevealHoldsTheValueAndHideDropsIt() async {
        answerList()
        StubURLProtocol.exchange.answer("/api/get", json: #"{"Value":"c2VjcmV0","Version":1}"#)
        await store.refresh()
        store.selectedName = "a/b"
        await store.reveal()
        XCTAssertEqual(store.revealed?.value, "secret")
        XCTAssertEqual(store.revealed?.version, 1)
        store.hide()
        XCTAssertNil(store.revealed)
    }

    func testChangingTheSelectionHidesARevealedValue() async {
        answerList(#"""
        [{"Name":"a/b","Versions":[1],"ActiveVersion":1},{"Name":"a/c","Versions":[1],"ActiveVersion":1}]
        """#)
        StubURLProtocol.exchange.answer("/api/get", json: #"{"Value":"c2VjcmV0","Version":1}"#)
        await store.refresh()
        store.selectedName = "a/b"
        await store.reveal()
        XCTAssertNotNil(store.revealed)
        store.selectedName = "a/c"
        XCTAssertNil(store.revealed)
    }
}
