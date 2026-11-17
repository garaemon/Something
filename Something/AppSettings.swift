import Combine
import Foundation
import HotKey

/// User preferences, saved to `UserDefaults` on every change.
@MainActor
final class AppSettings: ObservableObject {
    static let defaultHotKeyCombo = KeyCombo(key: .x, modifiers: [.command, .shift])
    /// `~/ghq`, the default root of ghq.
    static let defaultRepositoryRootPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("ghq").path
    /// `~/Downloads` and `~/Documents`.
    static let defaultFileFolderPaths = ["Downloads", "Documents"].map {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent($0).path
    }

    private enum StorageKey {
        static let hotKey = "hotKey"
        static let mascotHeadColor = "mascotHeadColor"
        static let mascotBodyColor = "mascotBodyColor"
        static let repositoryRootPath = "repositoryRootPath"
        static let fileFolderPaths = "fileFolderPaths"
        static let showsDockIcon = "showsDockIcon"
    }

    @Published var hotKeyCombo: KeyCombo {
        didSet { userDefaults.set(hotKeyCombo.dictionary, forKey: StorageKey.hotKey) }
    }
    /// "#RRGGBB".
    @Published var mascotHeadColor: String {
        didSet { userDefaults.set(mascotHeadColor, forKey: StorageKey.mascotHeadColor) }
    }
    /// "#RRGGBB".
    @Published var mascotBodyColor: String {
        didSet { userDefaults.set(mascotBodyColor, forKey: StorageKey.mascotBodyColor) }
    }
    /// Absolute path of the folder that the launcher scans for git
    /// repositories.
    @Published var repositoryRootPath: String {
        didSet { userDefaults.set(repositoryRootPath, forKey: StorageKey.repositoryRootPath) }
    }
    /// Absolute paths of the folders whose files the launcher lists.
    @Published var fileFolderPaths: [String] {
        didSet { userDefaults.set(fileFolderPaths, forKey: StorageKey.fileFolderPaths) }
    }
    /// False keeps the app out of the Dock and the Command-Tab switcher, so
    /// that only the hot key reaches the launcher.
    @Published var showsDockIcon: Bool {
        didSet { userDefaults.set(showsDockIcon, forKey: StorageKey.showsDockIcon) }
    }
    /// True while the settings window waits for a new hot key. The current hot
    /// key must be paused meanwhile, or Carbon takes the press before the window sees it.
    @Published var isRecordingHotKey = false

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let savedHotKey = (userDefaults.dictionary(forKey: StorageKey.hotKey)).flatMap(
            KeyCombo.init(dictionary:)
        )
        hotKeyCombo = savedHotKey ?? Self.defaultHotKeyCombo
        mascotHeadColor =
            userDefaults.string(forKey: StorageKey.mascotHeadColor) ?? MascotModel.defaultHeadColor
        mascotBodyColor =
            userDefaults.string(forKey: StorageKey.mascotBodyColor) ?? MascotModel.defaultBodyColor
        repositoryRootPath =
            userDefaults.string(forKey: StorageKey.repositoryRootPath)
            ?? Self.defaultRepositoryRootPath
        fileFolderPaths =
            userDefaults.stringArray(forKey: StorageKey.fileFolderPaths)
            ?? Self.defaultFileFolderPaths
        showsDockIcon = userDefaults.object(forKey: StorageKey.showsDockIcon) as? Bool ?? true
    }

    /// The robot painted with the chosen skin colors.
    var mascotModel: MascotModel {
        MascotModel.default.recolored(headColor: mascotHeadColor, bodyColor: mascotBodyColor)
    }

    /// Appends `path` to the file folders unless the list already holds it.
    func addFileFolder(_ path: String) {
        guard !fileFolderPaths.contains(path) else { return }
        fileFolderPaths.append(path)
    }

    func removeFileFolder(_ path: String) {
        fileFolderPaths.removeAll { $0 == path }
    }

    func resetToDefaults() {
        hotKeyCombo = Self.defaultHotKeyCombo
        mascotHeadColor = MascotModel.defaultHeadColor
        mascotBodyColor = MascotModel.defaultBodyColor
        repositoryRootPath = Self.defaultRepositoryRootPath
        fileFolderPaths = Self.defaultFileFolderPaths
        showsDockIcon = true
    }
}
