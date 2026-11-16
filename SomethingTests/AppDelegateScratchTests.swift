import XCTest

@testable import Something

@MainActor
final class AppDelegateScratchTests: XCTestCase {
    private func makeAppDelegate() -> AppDelegate {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppDelegateScratchTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folderURL) }
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [] })
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in [] })
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in [] })
        appDelegate.scratchStore = ScratchStore(fileURL: folderURL.appendingPathComponent("scratch.py"))
        addTeardownBlock { @MainActor in
            appDelegate.window?.close()
            appDelegate.scratchWindowController?.window.close()
        }
        return appDelegate
    }

    func test_should_show_scratch_window() {
        let appDelegate = makeAppDelegate()

        appDelegate.openScratch()

        XCTAssertEqual(appDelegate.scratchWindowController?.window.isVisible, true)
    }

    func test_should_reuse_scratch_window_when_opened_twice() {
        let appDelegate = makeAppDelegate()
        appDelegate.openScratch()
        let firstController = appDelegate.scratchWindowController

        appDelegate.openScratch()

        XCTAssertTrue(appDelegate.scratchWindowController === firstController)
    }

    func test_should_show_saved_text_in_scratch_window() throws {
        let appDelegate = makeAppDelegate()
        try appDelegate.scratchStore.saveText("x = 1\n")

        appDelegate.openScratch()

        XCTAssertEqual(appDelegate.scratchWindowController?.textView.string, "x = 1\n")
    }

    func test_should_save_text_when_scratch_window_closes() throws {
        let appDelegate = makeAppDelegate()
        appDelegate.openScratch()
        let controller = try XCTUnwrap(appDelegate.scratchWindowController)
        controller.textView.insertText("y = 2\n", replacementRange: NSRange(location: 0, length: 0))

        controller.window.close()

        XCTAssertTrue(appDelegate.scratchStore.loadText().hasPrefix("y = 2\n"))
    }

    func test_should_list_scratch_in_launcher() throws {
        let appDelegate = makeAppDelegate()
        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)

        launcherViewModel.query = "scratch"

        XCTAssertTrue(launcherViewModel.candidates.map(\.name).contains(ScratchSource.candidateName))
    }
}
