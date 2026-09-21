import XCTest
@testable import SetecUI

final class ServerSettingTests: XCTestCase {
    func testABareHostBecomesAnHTTPSURL() {
        XCTAssertEqual(ServerSetting.parse("setec.example.ts.net")?.absoluteString, "https://setec.example.ts.net")
        XCTAssertEqual(ServerSetting.parse(" http://localhost:8080 ")?.absoluteString, "http://localhost:8080")
        XCTAssertNil(ServerSetting.parse(""))
        XCTAssertNil(ServerSetting.parse("   "))
    }

    func testNothingIsConfiguredUntilTheStoredValueNamesAServer() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ServerSettingTests"))
        defaults.removePersistentDomain(forName: "ServerSettingTests")
        XCTAssertNil(ServerSetting.resolve(defaults: defaults), "the app carries no built-in server")
        defaults.set("https://other.example", forKey: ServerSetting.defaultsKey)
        XCTAssertEqual(ServerSetting.resolve(defaults: defaults)?.absoluteString, "https://other.example")
        defaults.removePersistentDomain(forName: "ServerSettingTests")
    }

    @MainActor
    func testAStoreWithoutAServerReportsItAndCallsNothing() async {
        let store = SecretStore(server: nil)
        XCTAssertEqual(store.loading, .unconfigured)
        await store.refresh()
        XCTAssertEqual(store.loading, .unconfigured, "refresh does not turn the absence into a failed call")
        XCTAssertNil(store.snapshot()["server"] as? String)
    }
}
