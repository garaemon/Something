import HotKey
import XCTest

@testable import Something

@MainActor
final class AppSettingsTests: XCTestCase {
    // Each test gets its own suite so that tests never read the user's real settings.
    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { userDefaults.removePersistentDomain(forName: suiteName) }
        return userDefaults
    }

    func test_should_use_command_shift_x_when_nothing_is_saved() {
        let settings = AppSettings(userDefaults: makeUserDefaults())

        XCTAssertEqual(
            settings.hotKeyBindings.map(\.keyCombo),
            [KeyCombo(key: .x, modifiers: [.command, .shift])]
        )
        XCTAssertEqual(settings.hotKeyBindings.map(\.command), [.openLauncher])
    }

    func test_should_restore_saved_hot_key() {
        let userDefaults = makeUserDefaults()
        let savedCombo = KeyCombo(key: .space, modifiers: [.option])
        AppSettings(userDefaults: userDefaults).hotKeyBindings = [
            HotKeyBinding(keyCombo: savedCombo, command: .openScratch)
        ]

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.hotKeyBindings.map(\.keyCombo), [savedCombo])
        XCTAssertEqual(restoredSettings.hotKeyBindings.map(\.command), [.openScratch])
    }

    func test_should_migrate_legacy_single_hot_key_to_open_launcher_binding() {
        let userDefaults = makeUserDefaults()
        let legacyCombo = KeyCombo(key: .space, modifiers: [.option])
        userDefaults.set(legacyCombo.dictionary, forKey: "hotKey")

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.hotKeyBindings.map(\.keyCombo), [legacyCombo])
        XCTAssertEqual(settings.hotKeyBindings.map(\.command), [.openLauncher])
    }

    func test_should_prefer_saved_bindings_over_legacy_hot_key() {
        let userDefaults = makeUserDefaults()
        userDefaults.set(KeyCombo(key: .space, modifiers: [.option]).dictionary, forKey: "hotKey")
        let savedCombo = KeyCombo(key: .j, modifiers: [.command, .option])
        AppSettings(userDefaults: userDefaults).hotKeyBindings = [
            HotKeyBinding(keyCombo: savedCombo, command: .openSettings)
        ]

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.hotKeyBindings.map(\.keyCombo), [savedCombo])
    }

    func test_should_keep_readable_bindings_when_one_saved_entry_is_corrupt() throws {
        let userDefaults = makeUserDefaults()
        let goodBinding = HotKeyBinding(
            keyCombo: KeyCombo(key: .j, modifiers: [.command, .option]), command: .openScratch)
        let goodJSON = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(goodBinding))
        let savedJSON = try JSONSerialization.data(
            withJSONObject: [goodJSON, ["id": "not-a-uuid"]])
        userDefaults.set(savedJSON, forKey: "hotKeyBindings")

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.hotKeyBindings, [goodBinding])
    }

    func test_should_reject_assigning_a_combo_that_another_binding_holds() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.addHotKeyBinding()
        let secondID = settings.hotKeyBindings[1].id

        let didAssign = settings.assignKeyCombo(AppSettings.defaultHotKeyCombo, toBindingID: secondID)

        XCTAssertFalse(didAssign)
    }

    func test_should_add_binding_with_distinct_combo() {
        let settings = AppSettings(userDefaults: makeUserDefaults())

        settings.addHotKeyBinding()

        XCTAssertNotEqual(settings.hotKeyBindings[0].keyCombo, settings.hotKeyBindings[1].keyCombo)
    }

    func test_should_remove_binding() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.addHotKeyBinding()

        settings.removeHotKeyBinding(id: settings.hotKeyBindings[1].id)

        XCTAssertEqual(settings.hotKeyBindings.count, 1)
    }

    func test_should_restore_saved_head_color() {
        let userDefaults = makeUserDefaults()
        AppSettings(userDefaults: userDefaults).mascotHeadColor = "#3366CC"

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.mascotHeadColor, "#3366CC")
    }

    func test_should_restore_saved_body_color() {
        let userDefaults = makeUserDefaults()
        AppSettings(userDefaults: userDefaults).mascotBodyColor = "#112233"

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.mascotBodyColor, "#112233")
    }

    func test_should_return_default_colors_after_reset() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.mascotHeadColor = "#000000"
        settings.mascotBodyColor = "#000000"

        settings.resetToDefaults()

        XCTAssertEqual(settings.mascotModel, MascotModel.default)
    }

    func test_should_return_default_hot_key_after_reset() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.addHotKeyBinding()

        settings.resetToDefaults()

        XCTAssertEqual(settings.hotKeyBindings.map(\.keyCombo), [AppSettings.defaultHotKeyCombo])
    }

    func test_should_use_ghq_under_home_as_repository_root_when_nothing_is_saved() {
        let settings = AppSettings(userDefaults: makeUserDefaults())

        XCTAssertEqual(
            settings.repositoryRootPath,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("ghq").path)
    }

    func test_should_restore_saved_repository_root() {
        let userDefaults = makeUserDefaults()
        AppSettings(userDefaults: userDefaults).repositoryRootPath = "/Users/someone/src"

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.repositoryRootPath, "/Users/someone/src")
    }

    func test_should_return_default_repository_root_after_reset() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.repositoryRootPath = "/Users/someone/src"

        settings.resetToDefaults()

        XCTAssertEqual(settings.repositoryRootPath, AppSettings.defaultRepositoryRootPath)
    }

    func test_should_use_downloads_and_documents_as_file_folders_when_nothing_is_saved() {
        let settings = AppSettings(userDefaults: makeUserDefaults())

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(settings.fileFolderPaths, ["\(homePath)/Downloads", "\(homePath)/Documents"])
    }

    func test_should_restore_saved_file_folders() {
        let userDefaults = makeUserDefaults()
        AppSettings(userDefaults: userDefaults).fileFolderPaths = ["/Users/someone/Desktop"]

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.fileFolderPaths, ["/Users/someone/Desktop"])
    }

    func test_should_restore_empty_file_folders() {
        let userDefaults = makeUserDefaults()
        AppSettings(userDefaults: userDefaults).fileFolderPaths = []

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.fileFolderPaths, [])
    }

    func test_should_return_default_file_folders_after_reset() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.fileFolderPaths = []

        settings.resetToDefaults()

        XCTAssertEqual(settings.fileFolderPaths, AppSettings.defaultFileFolderPaths)
    }

    func test_should_append_added_file_folder() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.fileFolderPaths = ["/a"]

        settings.addFileFolder("/b")

        XCTAssertEqual(settings.fileFolderPaths, ["/a", "/b"])
    }

    func test_should_not_add_file_folder_twice() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.fileFolderPaths = ["/a"]

        settings.addFileFolder("/a")

        XCTAssertEqual(settings.fileFolderPaths, ["/a"])
    }

    func test_should_remove_file_folder() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.fileFolderPaths = ["/a", "/b"]

        settings.removeFileFolder("/a")

        XCTAssertEqual(settings.fileFolderPaths, ["/b"])
    }

    func test_should_show_dock_icon_when_nothing_is_saved() {
        let settings = AppSettings(userDefaults: makeUserDefaults())

        XCTAssertTrue(settings.shouldShowDockIcon)
    }

    func test_should_restore_saved_dock_icon_visibility() {
        let userDefaults = makeUserDefaults()
        AppSettings(userDefaults: userDefaults).shouldShowDockIcon = false

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertFalse(restoredSettings.shouldShowDockIcon)
    }

    func test_should_show_dock_icon_after_reset() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.shouldShowDockIcon = false

        settings.resetToDefaults()

        XCTAssertTrue(settings.shouldShowDockIcon)
    }

    func test_should_open_launcher_at_last_position_when_nothing_is_saved() {
        let settings = AppSettings(userDefaults: makeUserDefaults())

        XCTAssertEqual(settings.launcherScreenPlacement, .lastPosition)
    }

    func test_should_restore_saved_launcher_screen_placement() {
        let userDefaults = makeUserDefaults()
        AppSettings(userDefaults: userDefaults).launcherScreenPlacement = .mouseScreen

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.launcherScreenPlacement, .mouseScreen)
    }

    func test_should_fall_back_to_last_position_for_an_unknown_saved_placement() {
        let userDefaults = makeUserDefaults()
        userDefaults.set("somewhere", forKey: "launcherScreenPlacement")

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.launcherScreenPlacement, .lastPosition)
    }

    func test_should_open_launcher_at_last_position_after_reset() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.launcherScreenPlacement = .primaryScreen

        settings.resetToDefaults()

        XCTAssertEqual(settings.launcherScreenPlacement, .lastPosition)
    }

    func test_should_default_org_directory_to_home_org() {
        let settings = AppSettings(userDefaults: makeUserDefaults())

        XCTAssertEqual(
            settings.orgDirectoryPath,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("org").path)
    }

    func test_should_restore_saved_org_directory() {
        let userDefaults = makeUserDefaults()
        AppSettings(userDefaults: userDefaults).orgDirectoryPath = "/tmp/notes"

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.orgDirectoryPath, "/tmp/notes")
    }

    func test_should_reset_org_directory_to_default() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.orgDirectoryPath = "/tmp/notes"

        settings.resetToDefaults()

        XCTAssertEqual(settings.orgDirectoryPath, AppSettings.defaultOrgDirectoryPath)
    }

    func test_should_use_local_ollama_defaults_for_llm_settings() {
        let settings = AppSettings(userDefaults: makeUserDefaults())

        XCTAssertEqual(settings.llmBaseURL, "http://localhost:11434/v1")
        XCTAssertEqual(settings.llmModelName, "")
    }

    func test_should_restore_saved_llm_settings() {
        let userDefaults = makeUserDefaults()
        let settings = AppSettings(userDefaults: userDefaults)
        settings.llmBaseURL = "http://localhost:1234/v1"
        settings.llmModelName = "gemma3"

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.llmBaseURL, "http://localhost:1234/v1")
        XCTAssertEqual(restoredSettings.llmModelName, "gemma3")
    }

    func test_should_return_default_llm_settings_after_reset() {
        let settings = AppSettings(userDefaults: makeUserDefaults())
        settings.llmBaseURL = "http://example.test/v1"
        settings.llmModelName = "gemma3"

        settings.resetToDefaults()

        XCTAssertEqual(settings.llmBaseURL, AppSettings.defaultLLMBaseURL)
        XCTAssertEqual(settings.llmModelName, "")
    }
}
