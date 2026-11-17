import Combine
import XCTest

@testable import Something

@MainActor
final class AppDelegateScriptTests: XCTestCase {
    private func makeAppDelegate(scriptCatalog: ScriptCatalog) -> AppDelegate {
        let suiteName = "AppDelegateScriptTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [] })
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in [] })
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in [] })
        appDelegate.scriptCatalog = scriptCatalog
        appDelegate.settings = AppSettings(userDefaults: UserDefaults(suiteName: suiteName)!)
        // The real call would switch the test host's own Dock icon.
        appDelegate.applyActivationPolicy = { _ in }
        addTeardownBlock { @MainActor in appDelegate.window?.close() }
        return appDelegate
    }

    func test_should_show_script_items_in_open_launcher() throws {
        let item = ScriptItem(generation: 1, source: "demo", title: "Scripted row", action: 0)
        let catalog = ScriptCatalog(runInitFile: {}, loadItems: { [item] }, runAction: { _, _ in })
        let appDelegate = makeAppDelegate(scriptCatalog: catalog)
        let itemsDelivered = expectation(description: "script items reach the open launcher")
        itemsDelivered.assertForOverFulfill = false

        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)
        launcherViewModel.query = "scripted"
        let candidatesSubscription = launcherViewModel.$candidates.sink { candidates in
            if candidates.contains(where: { $0.name == "Scripted row" }) {
                itemsDelivered.fulfill()
            }
        }

        wait(for: [itemsDelivered], timeout: 5)
        candidatesSubscription.cancel()
    }

    func test_should_run_python_action_of_picked_script_row_off_the_main_thread() throws {
        let item = ScriptItem(generation: 7, source: "demo", title: "Scripted row", action: 3)
        let actionRan = expectation(description: "the catalog runs the action")
        let catalog = ScriptCatalog(
            runInitFile: {},
            loadItems: { [item] },
            runAction: { generation, index in
                if generation == 7, index == 3, !Thread.isMainThread { actionRan.fulfill() }
            }
        )
        let appDelegate = makeAppDelegate(scriptCatalog: catalog)
        let itemsDelivered = expectation(description: "script items reach the open launcher")
        itemsDelivered.assertForOverFulfill = false
        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)
        launcherViewModel.query = "scripted"
        let candidatesSubscription = launcherViewModel.$candidates.sink { candidates in
            if candidates.contains(where: { $0.name == "Scripted row" }) {
                itemsDelivered.fulfill()
            }
        }
        wait(for: [itemsDelivered], timeout: 5)
        candidatesSubscription.cancel()

        let candidate = try XCTUnwrap(launcherViewModel.candidates.first { $0.name == "Scripted row" })
        candidate.defaultAction?.perform()

        wait(for: [actionRan], timeout: 5)
    }
}
