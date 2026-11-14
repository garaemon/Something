import XCTest

@testable import Something

@MainActor
final class AppDelegateTests: XCTestCase {
    // The test host crashes before the assertion when the bug is present, so
    // the crash, not the assertion, is what catches a regression.
    func test_should_not_crash_when_reopening_window_after_close() {
        let appDelegate = AppDelegate()
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
}
