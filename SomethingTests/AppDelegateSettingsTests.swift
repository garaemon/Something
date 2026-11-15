import XCTest

@testable import Something

@MainActor
final class AppDelegateSettingsTests: XCTestCase {
    private func makeAppDelegate() -> AppDelegate {
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [] })
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { [] })
        addTeardownBlock { @MainActor in
            appDelegate.window?.close()
            appDelegate.settingsWindow?.close()
        }
        return appDelegate
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
}
