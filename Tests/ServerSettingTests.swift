import XCTest
@testable import SetecUI

final class ServerSettingTests: XCTestCase {
    func testABareHostBecomesAnHTTPSURL() {
        XCTAssertEqual(ServerSetting.parse("setec.example.ts.net")?.absoluteString, "https://setec.example.ts.net")
        XCTAssertEqual(ServerSetting.parse(" http://localhost:8080 ")?.absoluteString, "http://localhost:8080")
        XCTAssertNil(ServerSetting.parse(""))
        XCTAssertNil(ServerSetting.parse("   "))
    }

    func testTheStoredValueIsPreferredOverTheBuiltInDefault() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ServerSettingTests"))
        defaults.removePersistentDomain(forName: "ServerSettingTests")
        XCTAssertEqual(ServerSetting.resolve(defaults: defaults), ServerSetting.fallback)
        defaults.set("https://other.example", forKey: ServerSetting.defaultsKey)
        XCTAssertEqual(ServerSetting.resolve(defaults: defaults).absoluteString, "https://other.example")
        defaults.removePersistentDomain(forName: "ServerSettingTests")
    }
}
