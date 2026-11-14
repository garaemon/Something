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
}
