import XCTest

@testable import Something

final class SettingsSourceTests: XCTestCase {
    func test_should_list_settings_for_settings_query() {
        let source = SettingsSource(openSettings: {})

        let names = source.makeCandidates(matching: "sett").map(\.name)

        XCTAssertEqual(names, [SettingsSource.candidateName])
    }

    func test_should_list_settings_for_preferences_query() {
        let source = SettingsSource(openSettings: {})

        let candidates = source.makeCandidates(matching: "pref")

        XCTAssertEqual(candidates.count, 1)
    }

    // The empty query lists every application, and a settings row at the top
    // would push them down.
    func test_should_list_nothing_for_empty_query() {
        let source = SettingsSource(openSettings: {})

        let candidates = source.makeCandidates(matching: "")

        XCTAssertTrue(candidates.isEmpty)
    }

    func test_should_list_nothing_for_unrelated_query() {
        let source = SettingsSource(openSettings: {})

        let candidates = source.makeCandidates(matching: "safari")

        XCTAssertTrue(candidates.isEmpty)
    }

    func test_should_open_settings_on_default_action() {
        var openCount = 0
        let source = SettingsSource(openSettings: { openCount += 1 })

        source.makeCandidates(matching: "settings").first?.defaultAction?.perform()

        XCTAssertEqual(openCount, 1)
    }
}
