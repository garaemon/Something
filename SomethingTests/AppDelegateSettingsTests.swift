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
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in [] })
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

    func test_should_list_settings_in_launcher() throws {
        let appDelegate = makeAppDelegate()
        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)

        launcherViewModel.query = "settings"

        XCTAssertTrue(launcherViewModel.candidates.map(\.name).contains(SettingsSource.candidateName))
    }

    func test_should_scan_repository_root_from_settings() {
        let appDelegate = makeAppDelegate()
        appDelegate.settings.repositoryRootPath = "/Users/someone/src"
        let scannedRoot = expectation(description: "the catalog scans the configured root")
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { rootDirectory in
            if rootDirectory.path == "/Users/someone/src" { scannedRoot.fulfill() }
            return []
        })

        appDelegate.openWindow()

        wait(for: [scannedRoot], timeout: 5)
    }

    func test_should_scan_again_when_repository_root_changes() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()
        let scannedNewRoot = expectation(description: "the catalog scans the new root")
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { rootDirectory in
            if rootDirectory.path == "/Users/someone/src" { scannedNewRoot.fulfill() }
            return []
        })

        appDelegate.settings.repositoryRootPath = "/Users/someone/src"

        wait(for: [scannedNewRoot], timeout: 5)
    }
}
