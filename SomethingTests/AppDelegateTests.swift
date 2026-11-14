import XCTest

@testable import Something

final class AppDelegateTests: XCTestCase {
    func test_should_reopen_window_after_closing_it() {
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        // Draining the pool is what triggers the over-release crash when a
        // closed window is released by both AppKit and ARC.
        autoreleasepool {
            appDelegate.openWindow()
            appDelegate.window?.close()
        }

        appDelegate.openWindow()

        XCTAssertNotNil(appDelegate.window)
        appDelegate.window?.close()
    }
}
