import XCTest

@testable import Something

@MainActor
final class AppDelegateLauncherRevealTests: XCTestCase {
    private func makeAppDelegate(loadWindows: @escaping () -> [SwitchableWindow]) -> AppDelegate {
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: loadWindows)
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in [] })
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in [] })
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        return appDelegate
    }

    func test_should_keep_launcher_hidden_until_window_list_arrives() {
        let loadRelease = DispatchSemaphore(value: 0)
        let appDelegate = makeAppDelegate(loadWindows: {
            loadRelease.wait()
            return []
        })
        addTeardownBlock { loadRelease.signal() }

        appDelegate.openWindow()

        XCTAssertEqual(appDelegate.window?.isVisible, false)
    }

    func test_should_show_loaded_windows_in_first_visible_frame() {
        let appDelegate = makeAppDelegate(loadWindows: { [makeWindow("Finder", "Downloads")] })

        appDelegate.openWindow()
        runMainLoop { appDelegate.window?.isVisible == true }

        XCTAssertEqual(appDelegate.launcherViewModel?.candidates.first?.name, "Finder — Downloads")
    }

    func test_should_show_launcher_when_window_list_misses_deadline() {
        let loadRelease = DispatchSemaphore(value: 0)
        let appDelegate = makeAppDelegate(loadWindows: {
            loadRelease.wait()
            return []
        })
        addTeardownBlock { loadRelease.signal() }
        appDelegate.windowListWaitTimeout = 0.05

        appDelegate.openWindow()
        runMainLoop { appDelegate.window?.isVisible == true }

        XCTAssertEqual(appDelegate.window?.isVisible, true)
    }

    func test_should_reuse_pending_launcher_on_second_open() {
        let loadRelease = DispatchSemaphore(value: 0)
        let appDelegate = makeAppDelegate(loadWindows: {
            loadRelease.wait()
            return []
        })
        addTeardownBlock { loadRelease.signal() }
        appDelegate.openWindow()
        let pendingWindow = appDelegate.window

        appDelegate.openWindow()

        XCTAssertTrue(appDelegate.window === pendingWindow)
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

        XCTAssertEqual(closedWindow?.isVisible, false)
    }
}
