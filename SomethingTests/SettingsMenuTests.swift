import AppKit
import XCTest

@testable import Something

// The app's own main menu is under test here, so the menu item reaches the
// AppDelegate of the test host, not one that the test creates.
@MainActor
final class SettingsMenuTests: XCTestCase {
    func test_should_open_settings_with_content_from_command_comma() throws {
        let menuItems = (NSApp.mainMenu?.items ?? []).flatMap { $0.submenu?.items ?? [] }
        let settingsItem = try XCTUnwrap(menuItems.first {
            $0.keyEquivalent == "," && $0.keyEquivalentModifierMask == .command
        })
        addTeardownBlock { @MainActor in
            NSApp.windows.filter { $0.title == SettingsSource.candidateName }.forEach { $0.close() }
        }

        NSApp.sendAction(try XCTUnwrap(settingsItem.action), to: settingsItem.target, from: settingsItem)

        let settingsWindows = NSApp.windows.filter { $0.isVisible && $0.title == SettingsSource.candidateName }
        XCTAssertTrue(settingsWindows.contains { ($0.contentView?.fittingSize.height ?? 0) > 0 })
    }
}
