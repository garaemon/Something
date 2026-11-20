import HotKey
import XCTest

@testable import Something

@MainActor
final class AppDelegateSettingsTests: XCTestCase {
    private func makeAppDelegate() -> AppDelegate {
        let suiteName = "AppDelegateSettingsTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
        let appDelegate = AppDelegate()
        appDelegate.applicationCatalog = ApplicationCatalog(searchDirectories: [])
        appDelegate.windowCatalog = WindowCatalog(loadWindows: { [] })
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in [] })
        appDelegate.fileCatalog = FileCatalog(loadFiles: { _ in [] })
        appDelegate.settings = AppSettings(userDefaults: UserDefaults(suiteName: suiteName)!)
        // The real call would switch the test host's own Dock icon.
        appDelegate.applyActivationPolicy = { _ in }
        // A real tap would swallow the developer's keystrokes.
        appDelegate.keyEventTapInstaller = FakeKeyEventTapInstaller()
        addTeardownBlock { @MainActor in
            appDelegate.window?.close()
            appDelegate.settingsWindow?.close()
        }
        return appDelegate
    }

    func test_should_register_hot_key_from_settings() {
        let appDelegate = makeAppDelegate()

        appDelegate.startObservingSettings()

        XCTAssertEqual(appDelegate.registeredHotKeys.map(\.keyCombo), [AppSettings.defaultHotKeyCombo])
    }

    func test_should_register_new_hot_key_when_setting_changes() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()
        let newCombo = KeyCombo(key: .j, modifiers: [.control, .option, .command])

        let bindingID = appDelegate.settings.hotKeyBindings[0].id
        appDelegate.settings.assignKeyCombo(newCombo, toBindingID: bindingID)

        XCTAssertEqual(appDelegate.registeredHotKeys.map(\.keyCombo), [newCombo])
    }

    func test_should_register_every_binding() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()

        appDelegate.settings.addHotKeyBinding()

        XCTAssertEqual(appDelegate.registeredHotKeys.count, 2)
    }

    func test_should_run_command_of_binding() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()
        appDelegate.settings.addHotKeyBinding()
        let bindingID = appDelegate.settings.hotKeyBindings[1].id
        appDelegate.settings.updateCommand(.openSettings, forBindingID: bindingID)

        appDelegate.registeredHotKeys[1].keyDownHandler?()

        XCTAssertEqual(appDelegate.settingsWindow?.isVisible, true)
    }

    func test_should_pause_hot_key_while_recording() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()

        appDelegate.settings.recordingBindingID = appDelegate.settings.hotKeyBindings[0].id

        XCTAssertEqual(appDelegate.registeredHotKeys.map(\.isPaused), [true])
    }

    func test_should_not_register_sided_binding_with_carbon() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()
        let bindingID = appDelegate.settings.hotKeyBindings[0].id

        appDelegate.settings.assignKeyCombo(
            KeyCombo(key: .e, modifiers: [.shift]),
            modifierSides: ModifierSides(shift: .right),
            toBindingID: bindingID)

        XCTAssertEqual(appDelegate.registeredHotKeys.count, 0)
    }

    func test_should_hand_sided_binding_to_the_event_tap() {
        let appDelegate = makeAppDelegate()
        let installer = FakeKeyEventTapInstaller()
        appDelegate.keyEventTapInstaller = installer
        appDelegate.isAccessibilityTrusted = { true }
        appDelegate.startObservingSettings()
        let bindingID = appDelegate.settings.hotKeyBindings[0].id

        appDelegate.settings.assignKeyCombo(
            KeyCombo(key: .e, modifiers: [.shift]),
            modifierSides: ModifierSides(shift: .right),
            toBindingID: bindingID)

        XCTAssertEqual(installer.installCount, 1)
    }

    func test_should_pause_sided_hot_keys_while_recording() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()

        appDelegate.settings.recordingBindingID = appDelegate.settings.hotKeyBindings[0].id

        XCTAssertTrue(appDelegate.sidedHotKeyMonitor.isPaused)
    }

    func test_should_show_settings_window() {
        let appDelegate = makeAppDelegate()

        appDelegate.openSettings()

        XCTAssertEqual(appDelegate.settingsWindow?.isVisible, true)
    }

    func test_should_reuse_settings_window_when_opened_twice() {
        let appDelegate = makeAppDelegate()
        appDelegate.openSettings()
        let firstWindow = appDelegate.settingsWindow

        appDelegate.openSettings()

        XCTAssertTrue(appDelegate.settingsWindow === firstWindow)
    }

    // The mascot preview keeps rendering while its view lives, so a closed
    // window must not keep it.
    func test_should_release_settings_content_when_closed() {
        let appDelegate = makeAppDelegate()
        appDelegate.openSettings()

        appDelegate.settingsWindow?.close()

        XCTAssertNil(appDelegate.settingsWindow?.contentView)
    }

    func test_should_show_settings_content_when_reopened_after_close() {
        let appDelegate = makeAppDelegate()
        appDelegate.openSettings()
        appDelegate.settingsWindow?.close()

        appDelegate.openSettings()

        XCTAssertNotNil(appDelegate.settingsWindow?.contentView)
    }

    func test_should_list_settings_in_launcher() throws {
        let appDelegate = makeAppDelegate()
        appDelegate.openWindow()
        let launcherViewModel = try XCTUnwrap(appDelegate.launcherViewModel)

        launcherViewModel.query = "settings"

        XCTAssertTrue(launcherViewModel.candidates.map(\.name).contains(SettingsSource.candidateName))
    }

    func test_should_scan_repository_root_from_settings() {
        let appDelegate = makeAppDelegate()
        appDelegate.settings.repositoryRootPath = "/Users/someone/src"
        let scannedRoot = expectation(description: "the catalog scans the configured root")
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { rootDirectory in
            if rootDirectory.path == "/Users/someone/src" { scannedRoot.fulfill() }
            return []
        })

        appDelegate.openWindow()

        wait(for: [scannedRoot], timeout: 5)
    }

    func test_should_scan_again_when_repository_root_changes() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()
        let scannedNewRoot = expectation(description: "the catalog scans the new root")
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { rootDirectory in
            if rootDirectory.path == "/Users/someone/src" { scannedNewRoot.fulfill() }
            return []
        })

        appDelegate.settings.repositoryRootPath = "/Users/someone/src"

        wait(for: [scannedNewRoot], timeout: 5)
    }

    // The settings are not observed here, so only the stale-scan check in the
    // finished scan can start the scan of the new root.
    func test_should_scan_new_root_when_root_changes_during_scan() {
        let appDelegate = makeAppDelegate()
        appDelegate.settings.repositoryRootPath = "/Users/someone/old"
        let scanRelease = DispatchSemaphore(value: 0)
        let scannedNewRoot = expectation(description: "the catalog scans the new root")
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { rootDirectory in
            if rootDirectory.path == "/Users/someone/new" {
                scannedNewRoot.fulfill()
            } else {
                scanRelease.wait()
            }
            return []
        })
        appDelegate.openWindow()

        appDelegate.settings.repositoryRootPath = "/Users/someone/new"
        scanRelease.signal()

        wait(for: [scannedNewRoot], timeout: 5)
    }

    func test_should_not_scan_when_same_repository_root_is_chosen_again() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()
        let repositoryScan = expectation(description: "the catalog scans again")
        repositoryScan.isInverted = true
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { _ in
            repositoryScan.fulfill()
            return []
        })

        appDelegate.settings.repositoryRootPath = AppSettings.defaultRepositoryRootPath

        wait(for: [repositoryScan], timeout: 0.5)
    }

    func test_should_not_scan_previous_root_when_repository_root_changes() {
        let appDelegate = makeAppDelegate()
        appDelegate.startObservingSettings()
        let previousRootScan = expectation(description: "the catalog scans the previous root")
        previousRootScan.isInverted = true
        appDelegate.repositoryCatalog = RepositoryCatalog(loadRepositories: { rootDirectory in
            if rootDirectory.path == AppSettings.defaultRepositoryRootPath { previousRootScan.fulfill() }
            return []
        })

        appDelegate.settings.repositoryRootPath = "/Users/someone/src"

        wait(for: [previousRootScan], timeout: 0.5)
    }

    func test_should_show_dock_icon_by_default() {
        let appDelegate = makeAppDelegate()
        var appliedPolicies: [NSApplication.ActivationPolicy] = []
        appDelegate.applyActivationPolicy = { appliedPolicies.append($0) }

        appDelegate.startObservingSettings()

        XCTAssertEqual(appliedPolicies, [.regular])
    }

    func test_should_hide_dock_icon_when_setting_turns_it_off() {
        let appDelegate = makeAppDelegate()
        var appliedPolicies: [NSApplication.ActivationPolicy] = []
        appDelegate.applyActivationPolicy = { appliedPolicies.append($0) }
        appDelegate.startObservingSettings()

        appDelegate.settings.shouldShowDockIcon = false

        XCTAssertEqual(appliedPolicies.last, .accessory)
    }
}
