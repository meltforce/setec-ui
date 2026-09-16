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
        // `use(server:)` in another test starts a refresh of its own, and the
        // exchange is shared, so the order is asserted on the writes alone.
        let calls = StubURLProtocol.exchange.requests.map(\.path).filter { $0 != "/api/list" }
        XCTAssertEqual(calls, ["/api/put", "/api/activate"])
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

    func testDeletingAVersionKeepsTheSecret() async {
        answerList(#"[{"Name":"a/b","Versions":[1,2],"ActiveVersion":1}]"#)
        StubURLProtocol.exchange.answer("/api/delete-version", json: "null")
        await store.refresh()
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

    func testTheReuseScanKeepsDigestsAndFindsTheSharedValue() async {
        let three = #"[{"Name":"a/x","Versions":[1],"ActiveVersion":1},"#
            + #"{"Name":"b/x","Versions":[1],"ActiveVersion":1},"#
            + #"{"Name":"c/x","Versions":[1],"ActiveVersion":1}]"#
        answerList(three)
        // Every get answers the same value, so all three share a digest.
        StubURLProtocol.exchange.answer("/api/get", json: #"{"Value":"c2FtZQ==","Version":1}"#)
        await store.refresh()
        XCTAssertNil(store.count(for: .reusedValue), "no scan, no answer")
        await store.scanForReuse()
        let scan = try? XCTUnwrap(store.reuseScan)
        XCTAssertEqual(scan?.digests.count, 3)
        XCTAssertEqual(scan?.digests["a/x"], ReuseScan.digest(of: "same"))
        XCTAssertEqual(store.reusedNames, ["a/x", "b/x", "c/x"])
        XCTAssertEqual(store.count(for: .reusedValue), 3)
        store.scope = .filter(.reusedValue)
        XCTAssertEqual(store.visible.count, 3)
    }

    func testAScanRecordsAFailureRatherThanCountingItAsUnique() async {
        answerList(#"[{"Name":"a/x","Versions":[1],"ActiveVersion":1}]"#)
        StubURLProtocol.exchange.answer("/api/get", status: 403, json: "null")
        await store.refresh()
        await store.scanForReuse()
        XCTAssertEqual(store.reuseScan?.digests.count, 0)
        XCTAssertEqual(store.reuseScan?.failures.keys.first, "a/x")
        XCTAssertEqual(store.reuseScan?.attempted, 1)
    }

    func testChangingTheServerDropsTheScan() async throws {
        answerList()
        StubURLProtocol.exchange.answer("/api/get", json: #"{"Value":"c2FtZQ==","Version":1}"#)
        await store.refresh()
        await store.scanForReuse()
        XCTAssertNotNil(store.reuseScan)
        try store.use(server: XCTUnwrap(URL(string: "https://other.example")))
        XCTAssertNil(store.reuseScan, "digests belong to the server they were read from")
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
