import Combine
import XCTest

@testable import Something

@MainActor
final class AppDelegateFileTests: XCTestCase {
    // The real file catalog walks ~/Documents, which asks for the Files and
    // Folders permission and would block the test run on a system dialog.
    private func makeAppDelegate() -> AppDelegate {
        let suiteName = "AppDelegateFileTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [] })
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in [] })
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in [] })
        appDelegate.settings = AppSettings(userDefaults: UserDefaults(suiteName: suiteName)!)
        // The real call would switch the test host's own Dock icon.
        appDelegate.applyActivationPolicy = { _ in }
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        return appDelegate
    }

    func test_should_show_listed_files_in_open_launcher() throws {
        let appDelegate = makeAppDelegate()
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in [makeFile("Downloads/report.pdf")] })
        let filesDelivered = expectation(description: "files reach the open launcher")
        filesDelivered.assertForOverFulfill = false

        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)
        launcherViewModel.query = "report"
        let candidatesSubscription = launcherViewModel.$candidates.sink { candidates in
            if candidates.contains(where: { $0.name == "Downloads/report.pdf" }) { filesDelivered.fulfill() }
        }

        wait(for: [filesDelivered], timeout: 5)
        candidatesSubscription.cancel()
    }

    func test_should_scan_file_folders_from_settings() {
        let appDelegate = makeAppDelegate()
        appDelegate.settings.fileFolderPaths = ["/Users/someone/Desktop"]
        let scannedFolders = expectation(description: "the catalog scans the configured folders")
        scannedFolders.assertForOverFulfill = false
        appDelegate.fileCatalog = FileCatalog(loadFiles: { folders in
            if folders.map(\.path) == ["/Users/someone/Desktop"] { scannedFolders.fulfill() }
            return []
        })

        appDelegate.openWindow()

        wait(for: [scannedFolders], timeout: 5)
    }

    func test_should_scan_again_when_file_folders_change() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()
        let scannedNewFolders = expectation(description: "the catalog scans the new folders")
        appDelegate.fileCatalog = FileCatalog(loadFiles: { folders in
            if folders.map(\.path) == ["/Users/someone/Desktop"] { scannedNewFolders.fulfill() }
            return []
        })

        appDelegate.settings.fileFolderPaths = ["/Users/someone/Desktop"]

        wait(for: [scannedNewFolders], timeout: 5)
    }
}
