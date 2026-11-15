import HotKey
import XCTest

@testable import Something

@MainActor
final class AppDelegateSettingsTests: XCTestCase {
    private func makeAppDelegate() -> AppDelegate {
        let suiteName = "AppDelegateSettingsTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [] })
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { [] })
        appDelegate.settings = AppSettings(userDefaults: UserDefaults(suiteName: suiteName)!)
        addTeardownBlock { @MainActor in
            appDelegate.window?.close()
            appDelegate.settingsWindow?.close()
        }
        return appDelegate
    }

    func test_should_register_hot_key_from_settings() {
        let appDelegate = makeAppDelegate()

        appDelegate.startObservingSettings()

        XCTAssertEqual(appDelegate.myHotKey?.keyCombo, AppSettings.defaultHotKeyCombo)
    }

    func test_should_register_new_hot_key_when_setting_changes() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()
        let newCombo = KeyCombo(key: .j, modifiers: [.control, .option, .command])

        appDelegate.settings.hotKeyCombo = newCombo

        XCTAssertEqual(appDelegate.myHotKey?.keyCombo, newCombo)
    }

    func test_should_pause_hot_key_while_recording() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()

        appDelegate.settings.isRecordingHotKey = true

        XCTAssertEqual(appDelegate.myHotKey?.isPaused, true)
    }

    func test_should_show_settings_window() {
        let appDelegate = makeAppDelegate()

        appDelegate.openSettings()

        XCTAssertEqual(appDelegate.settingsWindow?.isVisible, true)
    }

    func test_should_reuse_settings_window_when_opened_twice() {
        let appDelegate = makeAppDelegate()
        appDelegate.openSettings()
        let firstWindow = appDelegate.settingsWindow

        appDelegate.openSettings()

        XCTAssertTrue(appDelegate.settingsWindow === firstWindow)
    }

    // The mascot preview keeps rendering while its view lives, so a closed
    // window must not keep it.
    func test_should_release_settings_content_when_closed() {
        let appDelegate = makeAppDelegate()
        appDelegate.openSettings()

        appDelegate.settingsWindow?.close()

        XCTAssertNil(appDelegate.settingsWindow?.contentView)
    }

    func test_should_show_settings_content_when_reopened_after_close() {
        let appDelegate = makeAppDelegate()
        appDelegate.openSettings()
        appDelegate.settingsWindow?.close()

        appDelegate.openSettings()

        XCTAssertNotNil(appDelegate.settingsWindow?.contentView)
    }

    func test_should_list_settings_in_launcher() throws {
        let appDelegate = makeAppDelegate()
        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)

        launcherViewModel.query = "settings"

        XCTAssertTrue(launcherViewModel.candidates.map(\.name).contains(SettingsSource.candidateName))
    }
}
