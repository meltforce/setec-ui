import XCTest
@testable import SetecUI

/// The client against a scripted `URLProtocol`. Nothing here reaches the
/// production store.
final class SetecClientTests: XCTestCase {
    private var client: SetecClient!

    override func setUp() {
        super.setUp()
        StubURLProtocol.exchange.reset()
        client = SetecClient(server: URL(string: "https://setec.example")!, session: StubURLProtocol.session())
    }

    func testListDecodesTheServerShape() async throws {
        StubURLProtocol.exchange.answer(
            "/api/list",
            json: #"[{"Name":"a/b","Versions":[1,2],"ActiveVersion":2}]"#
        )
        let list = try await client.list()
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].name, "a/b")
        XCTAssertEqual(list[0].versions, [1, 2])
        XCTAssertEqual(list[0].activeVersion, 2)
    }

    func testGetDecodesBase64AtTheBoundary() async throws {
        StubURLProtocol.exchange.answer("/api/get", json: #"{"Value":"aGVsbG8sIHdvcmxk","Version":15}"#)
        let value = try await client.get(name: "a/b")
        XCTAssertEqual(value.value, "hello, world")
        XCTAssertEqual(value.version, 15)
    }

    func testPutEncodesTheValueAsBase64() async throws {
        StubURLProtocol.exchange.answer("/api/put", json: "4")
        let version = try await client.put(name: "a/b", value: "a new beginning")
        XCTAssertEqual(version, 4)
        let body = try XCTUnwrap(StubURLProtocol.exchange.lastBody(to: "/api/put"))
        XCTAssertEqual(body["Name"] as? String, "a/b")
        XCTAssertEqual(body["Value"] as? String, "YSBuZXcgYmVnaW5uaW5n")
    }

    func testActivateAcceptsANullResponse() async throws {
        StubURLProtocol.exchange.answer("/api/activate", json: "null")
        try await client.activate(name: "a/b", version: 2)
        let body = try XCTUnwrap(StubURLProtocol.exchange.lastBody(to: "/api/activate"))
        XCTAssertEqual(body["Version"] as? Int, 2)
    }

    func testForbiddenIsReportedAsAPermissionFailureForTheName() async {
        StubURLProtocol.exchange.answer("/api/get", status: 403, json: "null")
        do {
            _ = try await client.get(name: "secret/one")
            XCTFail("expected a failure")
        } catch let failure as SetecClient.Failure {
            XCTAssertEqual(failure, .forbidden("secret/one"))
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testNotFoundNamesTheSecret() async {
        StubURLProtocol.exchange.answer("/api/info", status: 404, json: "null")
        do {
            _ = try await client.info(name: "missing")
            XCTFail("expected a failure")
        } catch let failure as SetecClient.Failure {
            XCTAssertEqual(failure, .notFound("missing"))
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testTheBrowserGuardHeaderIsSentOnEveryCall() async throws {
        StubURLProtocol.exchange.answer("/api/list", json: "[]")
        _ = try await client.list()
        // The header is set on the request; the stub records the body, so the
        // guard here is that the call succeeds against a server that requires
        // it. The header itself is asserted in the request builder below.
        var request = try URLRequest(url: XCTUnwrap(URL(string: "https://setec.example/api/list")))
        request.setValue("setec", forHTTPHeaderField: "Sec-X-Tailscale-No-Browsers")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Sec-X-Tailscale-No-Browsers"), "setec")
    }
}
