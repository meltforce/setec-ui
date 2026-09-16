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
        XCTAssertTrue(app.searchFields.firstMatch.exists, "search is in the toolbar, not the sidebar")
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

    /// Copying moved from the action bar onto the value panel and appears on
    /// rollover. Hovering is what makes it exist; the test does what a person
    /// does. It presses nothing — a press would fetch a production value.
    @MainActor
    func testTheCopyButtonAppearsWhenTheValuePanelIsHovered() {
        let app = launch()
        let list = app.descendants(matching: .any).matching(identifier: "secrets.list").firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 15))
        let card = list.cells.firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.click()
        let panel = app.descendants(matching: .any).matching(identifier: "value.panel").firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["value.copy"].exists, "hidden until the pointer is on the panel")
        panel.hover()
        let copy = app.buttons["value.copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["detail.copy"].exists, "the action bar no longer carries it")

        // Size and placement, which a screenshot cannot be made to show from
        // here: a synthesized pointer does not reach SwiftUI's `onHover`.
        XCTAssertGreaterThanOrEqual(copy.frame.height, 20, "not a miniature control")
        let panelCentre = panel.frame.midY
        XCTAssertEqual(copy.frame.midY, panelCentre, accuracy: 3, "centred against the value")
    }

    /// The overflow button is a real `Button` with an `NSMenu`, because
    /// SwiftUI's `Menu` drops its background when given the round shape.
    @MainActor
    func testTheOverflowButtonOpensItsMenu() {
        let app = launch()
        let list = app.descendants(matching: .any).matching(identifier: "secrets.list").firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 15))
        list.cells.firstMatch.click()
        let more = app.buttons["detail.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        XCTAssertEqual(more.frame.width, more.frame.height, accuracy: 2, "round, so square in its frame")
        more.click()
        XCTAssertTrue(app.menuItems["Copy name"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.menuItems["Delete secret …"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    /// The rights the OAuth client needs are stated in the dialog that
    /// configures it, so they do not have to be looked up elsewhere.
    @MainActor
    func testTheAccessMatrixSettingsStateTheScopeItNeeds() {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows["Access matrix"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5) || app.windows.count > 1)
        app.buttons["Access matrix"].firstMatch.click()
        let scope = app.staticTexts["settings.access.requiredScope"].firstMatch
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        XCTAssertEqual(scope.value as? String, "policy_file:read")
        XCTAssertTrue(app.textFields["settings.access.id"].exists)
        XCTAssertTrue(app.textFields["settings.access.secret"].exists)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "settings.access.grantedScopes").firstMatch.exists)
    }

    @MainActor
    func testTheSidebarSelectsAFilter() {
        let app = launch()
        let row = app.staticTexts["sidebar.filter.multipleVersions"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        XCTAssertTrue(app.staticTexts["Multiple versions"].firstMatch.exists)
    }
}
