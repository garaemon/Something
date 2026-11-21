import Combine
import XCTest

@testable import Something

@MainActor
final class AppDelegateTests: XCTestCase {
    // The real catalogs scan the disk and ask for the Accessibility
    // permission, which would block the test run on a system dialog.
    private func makeAppDelegate() -> AppDelegate {
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [] })
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in [] })
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in [] })
        appDelegate.quicklinkStore = QuicklinkStore(fileURL: URL(fileURLWithPath: "/nonexistent/quicklinks.json"))
        return appDelegate
    }

    // The test host crashes before the assertion when the bug is present, so
    // the crash, not the assertion, is what catches a regression.
    func test_should_not_crash_when_reopening_window_after_close() {
        let appDelegate = makeAppDelegate()
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        // Draining the pool is what triggers the over-release crash when a
        // closed window is released by both AppKit and ARC.
        autoreleasepool {
            appDelegate.openWindow()
            appDelegate.window?.close()
        }

        appDelegate.openWindow()

        XCTAssertNotNil(appDelegate.window)
    }

    func test_should_show_scanned_applications_in_open_launcher() throws {
        let applicationsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: applicationsDirectory.appendingPathComponent("Fake.app"),
            withIntermediateDirectories: true)
        let appDelegate = makeAppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [applicationsDirectory])
        addTeardownBlock { @MainActor in
            appDelegate.window?.close()
            try? FileManager.default.removeItem(at: applicationsDirectory)
        }
        let scanDelivered = expectation(description: "scan reaches the open launcher")
        scanDelivered.assertForOverFulfill = false

        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)
        let candidatesSubscription = launcherViewModel.$candidates.sink { candidates in
            if candidates.map(\.name) == ["Fake"] { scanDelivered.fulfill() }
        }

        wait(for: [scanDelivered], timeout: 5)
        candidatesSubscription.cancel()
    }

    func test_should_list_quicklink_from_file_in_open_launcher() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("quicklinks.json")
        try #"[{"name": "zzlink", "url": "https://example.com/{query}"}]"#
            .write(to: fileURL, atomically: true, encoding: .utf8)
        let appDelegate = makeAppDelegate()
        appDelegate.quicklinkStore = QuicklinkStore(fileURL: fileURL)
        addTeardownBlock { @MainActor in
            appDelegate.window?.close()
            try? FileManager.default.removeItem(at: directoryURL)
        }

        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)
        launcherViewModel.query = "zzlink"

        XCTAssertEqual(launcherViewModel.candidates.first?.kind, .quicklink)
    }

    func test_should_show_listed_repositories_in_open_launcher() throws {
        let appDelegate = makeAppDelegate()
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in
            [makeRepository("github.com/a/b")]
        })
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        let repositoriesDelivered = expectation(description: "repositories reach the open launcher")
        repositoriesDelivered.assertForOverFulfill = false

        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)
        let candidatesSubscription = launcherViewModel.$candidates.sink { candidates in
            if candidates.map(\.name) == ["github.com/a/b"] { repositoriesDelivered.fulfill() }
        }

        wait(for: [repositoriesDelivered], timeout: 5)
        candidatesSubscription.cancel()
    }

    func test_should_not_queue_another_repository_scan_while_one_is_running() {
        let appDelegate = makeAppDelegate()
        let scanRelease = DispatchSemaphore(value: 0)
        let repositoryScans = expectation(description: "a second repository scan runs")
        repositoryScans.isInverted = true
        repositoryScans.expectedFulfillmentCount = 2
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in
            repositoryScans.fulfill()
            scanRelease.wait()
            return []
        })
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        appDelegate.openWindow()
        appDelegate.window?.close()

        appDelegate.openWindow()
        scanRelease.signal()
        scanRelease.signal()

        wait(for: [repositoryScans], timeout: 0.5)
    }

    func test_should_scan_repositories_again_on_open_after_previous_scan_finishes() throws {
        let appDelegate = makeAppDelegate()
        let twoScans = expectation(description: "repositories are scanned on both opens")
        twoScans.expectedFulfillmentCount = 2
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in
            twoScans.fulfill()
            return [makeRepository("github.com/a/b")]
        })
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        let firstLoadDelivered = expectation(description: "first load reaches the launcher")
        firstLoadDelivered.assertForOverFulfill = false
        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)
        let candidatesSubscription = launcherViewModel.$candidates.sink { candidates in
            if candidates.map(\.name) == ["github.com/a/b"] { firstLoadDelivered.fulfill() }
        }
        wait(for: [firstLoadDelivered], timeout: 5)
        candidatesSubscription.cancel()
        appDelegate.window?.close()

        appDelegate.openWindow()

        wait(for: [twoScans], timeout: 5)
    }

    func test_should_hand_selection_captured_before_opening_to_launcher() throws {
        let appDelegate = makeAppDelegate()
        let selection = CapturedSelection(
            sourceApplication: SourceApplication(
                processIdentifier: 100, bundleIdentifier: nil, name: "Safari"),
            text: "selected")
        appDelegate.captureSelection = { selection }
        addTeardownBlock { @MainActor in appDelegate.window?.close() }

        appDelegate.openWindow()

        XCTAssertEqual(appDelegate.launcherViewModel?.capturedSelection, selection)
    }

    func test_should_show_listed_windows_in_open_launcher() throws {
        let appDelegate = makeAppDelegate()
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [makeWindow("Safari", "GitHub")] })
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        let windowsDelivered = expectation(description: "windows reach the open launcher")
        windowsDelivered.assertForOverFulfill = false

        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)
        let candidatesSubscription = launcherViewModel.$candidates.sink { candidates in
            if candidates.map(\.name) == ["Safari — GitHub"] { windowsDelivered.fulfill() }
        }

        wait(for: [windowsDelivered], timeout: 5)
        candidatesSubscription.cancel()
    }

    func test_should_not_show_windows_listed_for_a_closed_launcher() throws {
        let appDelegate = makeAppDelegate()
        let staleLoadRelease = DispatchSemaphore(value: 0)
        appDelegate.windowCatalog = WindowCatalog(loadWindows: {
            staleLoadRelease.wait()
            return [makeWindow("Safari", "Stale")]
        })
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        appDelegate.openWindow()
        appDelegate.window?.close()
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [makeWindow("Safari", "Fresh")] })
        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)
        var observedNames: [String] = []
        let freshDelivered = expectation(description: "fresh windows reach the open launcher")
        freshDelivered.assertForOverFulfill = false
        let candidatesSubscription = launcherViewModel.$candidates.sink { candidates in
            observedNames += candidates.map(\.name)
            if candidates.map(\.name) == ["Safari — Fresh"] { freshDelivered.fulfill() }
        }

        staleLoadRelease.signal()
        wait(for: [freshDelivered], timeout: 5)
        candidatesSubscription.cancel()

        XCTAssertFalse(observedNames.contains("Safari — Stale"))
    }

    func test_should_place_the_mascot_where_the_chooser_picks() throws {
        let appDelegate = makeAppDelegate()
        appDelegate.chooseMascotPlacement = { _ in .left }
        addTeardownBlock { @MainActor in appDelegate.window?.close() }

        appDelegate.openWindow()

        XCTAssertEqual(try XCTUnwrap(appDelegate.mascotPanel).placement, .left)
    }

    func test_should_open_launcher_when_dock_icon_is_clicked() {
        let appDelegate = makeAppDelegate()
        addTeardownBlock { @MainActor in appDelegate.window?.close() }

        _ = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)

        XCTAssertEqual(appDelegate.window?.isVisible, true)
    }
}
