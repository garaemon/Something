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

        XCTAssertEqual(settings.hotKeyCombo, KeyCombo(key: .x, modifiers: [.command, .shift]))
    }

    func test_should_restore_saved_hot_key() {
        let userDefaults = makeUserDefaults()
        let savedCombo = KeyCombo(key: .space, modifiers: [.option])
        AppSettings(userDefaults: userDefaults).hotKeyCombo = savedCombo

        let restoredSettings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(restoredSettings.hotKeyCombo, savedCombo)
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
        settings.hotKeyCombo = KeyCombo(key: .space, modifiers: [.option])

        settings.resetToDefaults()

        XCTAssertEqual(settings.hotKeyCombo, AppSettings.defaultHotKeyCombo)
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
}
