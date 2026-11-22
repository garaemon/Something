import XCTest

@testable import Something

@MainActor
final class AppDelegateLauncherRevealTests: XCTestCase {
    // Longer than any test waits, so that only the window list reveals the launcher.
    private static let unreachedTimeout: TimeInterval = 60

    private func makeAppDelegate(loadWindows: @escaping () -> [SwitchableWindow]) -> AppDelegate {
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: loadWindows)
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in [] })
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in [] })
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        return appDelegate
    }

    // Returns a delegate whose window list never arrives until the test ends.
    private func makeAppDelegateWithStalledWindowList() -> AppDelegate {
        let loadRelease = DispatchSemaphore(value: 0)
        addTeardownBlock { loadRelease.signal() }
        return makeAppDelegate(loadWindows: {
            loadRelease.wait()
            return []
        })
    }

    private func isLauncherShown(_ appDelegate: AppDelegate) -> Bool {
        appDelegate.window?.isVisible == true && appDelegate.window?.alphaValue == 1
    }

    func test_should_keep_launcher_transparent_until_window_list_arrives() {
        let appDelegate = makeAppDelegateWithStalledWindowList()
        appDelegate.windowListWaitTimeout = Self.unreachedTimeout

        appDelegate.openWindow()

        XCTAssertEqual(appDelegate.window?.alphaValue, 0)
    }

    // Keystrokes typed during the wait reach the launcher, not the app in front.
    func test_should_order_launcher_front_before_window_list_arrives() {
        let appDelegate = makeAppDelegateWithStalledWindowList()
        appDelegate.windowListWaitTimeout = Self.unreachedTimeout

        appDelegate.openWindow()

        XCTAssertEqual(appDelegate.window?.isVisible, true)
    }

    func test_should_show_loaded_windows_in_first_visible_frame() {
        let appDelegate = makeAppDelegate(loadWindows: { [makeWindow("Finder", "Downloads")] })
        appDelegate.windowListWaitTimeout = Self.unreachedTimeout

        appDelegate.openWindow()
        runMainLoop { self.isLauncherShown(appDelegate) }

        XCTAssertEqual(appDelegate.launcherViewModel?.candidates.first?.name, "Finder — Downloads")
    }

    func test_should_show_launcher_when_window_list_misses_deadline() {
        let appDelegate = makeAppDelegateWithStalledWindowList()
        appDelegate.windowListWaitTimeout = 0.05

        appDelegate.openWindow()
        runMainLoop { self.isLauncherShown(appDelegate) }

        XCTAssertTrue(isLauncherShown(appDelegate))
    }

    func test_should_reuse_pending_launcher_on_second_open() {
        let appDelegate = makeAppDelegateWithStalledWindowList()
        appDelegate.windowListWaitTimeout = Self.unreachedTimeout
        appDelegate.openWindow()
        let pendingWindow = appDelegate.window

        appDelegate.openWindow()

        XCTAssertTrue(appDelegate.window === pendingWindow)
    }

    func test_should_show_pending_launcher_at_once_on_second_open() {
        let appDelegate = makeAppDelegateWithStalledWindowList()
        appDelegate.windowListWaitTimeout = Self.unreachedTimeout
        appDelegate.openWindow()

        appDelegate.openWindow()

        XCTAssertTrue(isLauncherShown(appDelegate))
    }

    func test_should_not_show_launcher_closed_before_window_list_arrives() {
        let loadRelease = DispatchSemaphore(value: 0)
        let appDelegate = makeAppDelegate(loadWindows: {
            loadRelease.wait()
            return []
        })
        appDelegate.windowListWaitTimeout = 0.05
        appDelegate.openWindow()
        let closedWindow = appDelegate.window
        closedWindow?.close()

        loadRelease.signal()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(closedWindow?.alphaValue, 0)
    }
}
