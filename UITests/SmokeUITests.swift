import XCTest

/// The regression floor: the app launches, the three columns render, the
/// sidebar and the list answer selection, and the sheets open and close. The
/// app talks to the real server on launch, so nothing here asserts a secret
/// name — only the shell and the controls.
final class SmokeUITests: XCTestCase {
    /// Without this, AppKit's window restoration for the bundle id can leave a
    /// test-launched app with no window at all (INCIDENTS.md, 2026-09-15).
    private let ignoreSavedState = ["-ApplePersistenceIgnoreState", "YES"]

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ignoreSavedState
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    func testLaunchShowsTheShell() {
        let app = launch()
        XCTAssertTrue(app.outlines["sidebar.list"].exists || app.tables["sidebar.list"].exists
            || app.otherElements["sidebar.list"].exists)
        XCTAssertTrue(app.buttons["toolbar.refresh"].exists)
        XCTAssertTrue(app.buttons["toolbar.newSecret"].exists)
        XCTAssertTrue(app.staticTexts["toolbar.identity"].exists)
    }

    @MainActor
    func testTheDetailColumnStartsWithoutASelection() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["No secret selected"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNewSecretSheetOpensAndCancels() {
        let app = launch()
        app.buttons["toolbar.newSecret"].click()
        let name = app.textFields["newSecret.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["newSecret.generate"].exists)
        XCTAssertFalse(app.buttons["newSecret.submit"].isEnabled, "an empty form cannot be submitted")
        app.buttons["newSecret.cancel"].click()
        XCTAssertFalse(name.waitForExistence(timeout: 2))
    }

    @MainActor
    func testTheNameFieldReportsAnInvalidName() {
        let app = launch()
        app.buttons["toolbar.newSecret"].click()
        let name = app.textFields["newSecret.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Not/A/Valid")
        XCTAssertTrue(app.staticTexts["Lowercase, digits, . _ - and / only"].waitForExistence(timeout: 3))
        app.buttons["newSecret.cancel"].click()
    }

    /// Both destructive paths are sheets in the app's own visual language, so
    /// both are reachable here. This one opens and cancels; it deletes nothing.
    @MainActor
    func testTheDeleteSecretSheetStaysInertUntilTheNameMatches() {
        let app = launch()
        let row = app.staticTexts["sidebar.filter.multipleVersions"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.click()
        let list = app.descendants(matching: .any).matching(identifier: "secrets.list").firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        let card = list.cells.firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.click()
        XCTAssertTrue(app.staticTexts["detail.title"].waitForExistence(timeout: 5), "a secret is selected")
        app.menuBars.menuItems["Delete Secret…"].click()
        let field = app.textFields["deleteSecret.confirmName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["deleteSecret.submit"].isEnabled)
        XCTAssertTrue(app.staticTexts["deleteSecret.hint"].exists)
        app.buttons["deleteSecret.cancel"].click()
        XCTAssertFalse(field.waitForExistence(timeout: 2))
    }

    @MainActor
    func testTheSidebarSelectsAFilter() {
        let app = launch()
        let row = app.staticTexts["sidebar.filter.noRollback"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        XCTAssertTrue(app.staticTexts["No rollback version"].firstMatch.exists)
    }
}
