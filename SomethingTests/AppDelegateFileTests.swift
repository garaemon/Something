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

    // The settings are not observed here, so only the stale-scan check in the
    // finished scan can start the scan of the new folders.
    func test_should_scan_new_folders_when_folders_change_during_scan() {
        let appDelegate = makeAppDelegate()
        appDelegate.settings.fileFolderPaths = ["/Users/someone/old"]
        let scanRelease = DispatchSemaphore(value: 0)
        let scannedNewFolders = expectation(description: "the catalog scans the new folders")
        appDelegate.fileCatalog = FileCatalog(loadFiles: { folders in
            if folders.map(\.path) == ["/Users/someone/new"] {
                scannedNewFolders.fulfill()
            } else {
                scanRelease.wait()
            }
            return []
        })
        appDelegate.openWindow()

        appDelegate.settings.fileFolderPaths = ["/Users/someone/new"]
        scanRelease.signal()

        wait(for: [scannedNewFolders], timeout: 5)
    }

    func test_should_not_queue_another_file_scan_while_one_is_running() {
        let appDelegate = makeAppDelegate()
        let scanRelease = DispatchSemaphore(value: 0)
        let fileScans = expectation(description: "a second file scan runs")
        fileScans.isInverted = true
        fileScans.expectedFulfillmentCount = 2
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in
            fileScans.fulfill()
            scanRelease.wait()
            return []
        })
        appDelegate.openWindow()
        appDelegate.window?.close()

        appDelegate.openWindow()
        scanRelease.signal()
        scanRelease.signal()

        wait(for: [fileScans], timeout: 0.5)
    }
}
