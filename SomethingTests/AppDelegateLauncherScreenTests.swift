import AppKit
import XCTest

@testable import Something

@MainActor
final class AppDelegateLauncherScreenTests: XCTestCase {
    private func makeAppDelegate(placement: LauncherScreenPlacement) -> AppDelegate {
        let suiteName = "AppDelegateLauncherScreenTests-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
        let appDelegate = AppDelegate()
        appDelegate.settings = AppSettings(userDefaults: UserDefaults(suiteName: suiteName)!)
        appDelegate.settings.launcherScreenPlacement = placement
        // The real catalogs scan the disk and ask for the Accessibility permission.
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [] })
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in [] })
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in [] })
        appDelegate.quicklinkStore = QuicklinkStore(
            fileURL: URL(fileURLWithPath: "/nonexistent/quicklinks.json")
        )
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        return appDelegate
    }

    func test_should_keep_restored_position_for_last_position() {
        let appDelegate = makeAppDelegate(placement: .lastPosition)

        XCTAssertNil(appDelegate.launcherTargetScreen())
    }

    func test_should_pick_the_primary_screen_for_menu_bar_placement() {
        let appDelegate = makeAppDelegate(placement: .primaryScreen)

        XCTAssertEqual(appDelegate.launcherTargetScreen(), NSScreen.screens.first)
    }

    func test_should_pick_a_screen_for_mouse_placement() {
        let appDelegate = makeAppDelegate(placement: .mouseScreen)

        XCTAssertNotNil(appDelegate.launcherTargetScreen())
    }

    func test_should_pick_a_screen_for_active_window_placement() {
        let appDelegate = makeAppDelegate(placement: .activeWindowScreen)

        XCTAssertNotNil(appDelegate.launcherTargetScreen())
    }

    func test_should_open_the_launcher_inside_the_target_screen() throws {
        let appDelegate = makeAppDelegate(placement: .primaryScreen)
        let screen = try XCTUnwrap(NSScreen.screens.first)

        appDelegate.openWindow()

        let window = try XCTUnwrap(appDelegate.window)
        XCTAssertTrue(screen.visibleFrame.contains(window.frame))
    }
}
