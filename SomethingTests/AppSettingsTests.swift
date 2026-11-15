import HotKey
import XCTest

@testable import Something

@MainActor
final class AppSettingsTests: XCTestCase {
    // Each test gets its own suite so that tests never read the user's real settings.
    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { userDefaults.removePersistentDomain(forName: suiteName) }
        return userDefaults
    }

    func test_should_use_command_shift_x_when_nothing_is_saved() {
        let settings = AppSettings(userDefaults: makeUserDefaults())

        XCTAssertEqual(settings.hotKeyCombo, KeyCombo(key: .x, modifiers: [.command, .shift]))
    }

    func test_should_restore_saved_hot_key() {
        let userDefaults = makeUserDefaults()
        let savedCombo = KeyCombo(key: .space, modifiers: [.option])
        AppSettings(userDefaults: userDefaults).hotKeyCombo = savedCombo

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.hotKeyCombo, savedCombo)
    }

    func test_should_return_default_hot_key_after_reset() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.hotKeyCombo = KeyCombo(key: .space, modifiers: [.option])

        settings.resetToDefaults()

        XCTAssertEqual(settings.hotKeyCombo, AppSettings.defaultHotKeyCombo)
    }
}
