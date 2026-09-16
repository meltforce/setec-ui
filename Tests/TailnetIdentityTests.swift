import XCTest
@testable import SetecUI

final class TailnetIdentityTests: XCTestCase {
    func testParsingTheCLIStatus() throws {
        let json = """
        {
          "BackendState": "Running",
          "Self": {"UserID": 6751585560508670, "DNSName": "mac.example.ts.net.", "HostName": "mac"},
          "User": {"6751585560508670": {"LoginName": "person@example.com", "DisplayName": "A Person"}}
        }
        """
        let identity = try XCTUnwrap(TailnetIdentity.parse(Data(json.utf8)))
        XCTAssertEqual(identity.loginName, "person@example.com")
        XCTAssertEqual(identity.nodeName, "mac.example.ts.net", "the trailing dot is removed")
        XCTAssertEqual(identity.shortLogin, "person@example")
    }

    func testOutputWithoutAMatchingUserIsRejectedRatherThanGuessed() {
        let json = #"{"Self": {"UserID": 1, "DNSName": "mac."}, "User": {}}"#
        XCTAssertNil(TailnetIdentity.parse(Data(json.utf8)))
        XCTAssertNil(TailnetIdentity.parse(Data("not json".utf8)))
    }
}
