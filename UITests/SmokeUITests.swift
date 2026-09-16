import XCTest

/// The regression floor: the app launches, the shell renders, the menu
/// command reaches its handler. Feature tests are added when a verification
/// step in a plan names them.
final class SmokeUITests: XCTestCase {
    /// Without this, AppKit's window restoration for the bundle id can leave a
    /// test-launched app with no window at all (INCIDENTS.md, 2026-09-15).
    private let ignoreSavedState = ["-ApplePersistenceIgnoreState", "YES"]

    @MainActor
    func testLaunchShowsTheShell() {
        let app = XCUIApplication()
        app.launchArguments = ignoreSavedState
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.outlines["sidebar.list"].exists || app.tables["sidebar.list"].exists
            || app.otherElements["sidebar.list"].exists)
        XCTAssertTrue(app.buttons["toolbar.inspector"].exists)
    }

    @MainActor
    func testNewItemCommandAddsARow() {
        let app = XCUIApplication()
        app.launchArguments = ignoreSavedState
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        app.typeKey("n", modifierFlags: .command)
        let field = app.textFields["inspector.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "New Item")
    }
}
