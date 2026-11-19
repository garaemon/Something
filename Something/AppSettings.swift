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

    /// Ollama's OpenAI-compatible endpoint.
    static let defaultLLMBaseURL = "http://localhost:11434/v1"
    // Empty until the user picks a model, because each runtime lists its own.
    // TODO(garaemon): Report a missing model before the request, instead of
    // the server's HTTP error, once an AI command calls LocalLLMProvider.
    static let defaultLLMModelName = ""

    private enum StorageKey {
        // Before bindings existed, the settings held this single launcher hot key.
        static let legacyHotKey = "hotKey"
        static let hotKeyBindings = "hotKeyBindings"
        static let mascotHeadColor = "mascotHeadColor"
        static let mascotBodyColor = "mascotBodyColor"
        static let repositoryRootPath = "repositoryRootPath"
        static let fileFolderPaths = "fileFolderPaths"
        static let shouldShowDockIcon = "shouldShowDockIcon"
        static let llmBaseURL = "llmBaseURL"
        static let llmModelName = "llmModelName"
    }

    /// Global hot keys and the commands they run.
    @Published var hotKeyBindings: [HotKeyBinding] {
        didSet { saveHotKeyBindings() }
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
    @Published var shouldShowDockIcon: Bool {
        didSet { userDefaults.set(shouldShowDockIcon, forKey: StorageKey.shouldShowDockIcon) }
    }
    /// Base URL of the local OpenAI-compatible server that AI commands call.
    @Published var llmBaseURL: String {
        didSet { userDefaults.set(llmBaseURL, forKey: StorageKey.llmBaseURL) }
    }
    /// Model that the local server runs, such as "gemma3".
    @Published var llmModelName: String {
        didSet { userDefaults.set(llmModelName, forKey: StorageKey.llmModelName) }
    }
    /// True while the settings window waits for a new hot key. Every binding
    /// must be paused meanwhile, or Carbon takes the press before the window sees it.
    @Published var recordingBindingID: UUID?

    var isRecordingHotKey: Bool { recordingBindingID != nil }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        hotKeyBindings = Self.loadHotKeyBindings(from: userDefaults)
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
        shouldShowDockIcon =
            userDefaults.object(forKey: StorageKey.shouldShowDockIcon) as? Bool ?? true
        llmBaseURL = userDefaults.string(forKey: StorageKey.llmBaseURL) ?? Self.defaultLLMBaseURL
        llmModelName =
            userDefaults.string(forKey: StorageKey.llmModelName) ?? Self.defaultLLMModelName
    }

    private static func loadHotKeyBindings(from userDefaults: UserDefaults) -> [HotKeyBinding] {
        let savedBindings = userDefaults.data(forKey: StorageKey.hotKeyBindings).flatMap {
            try? JSONDecoder().decode([LossyBinding].self, from: $0)
        }
        if let savedBindings { return savedBindings.compactMap(\.binding) }
        let legacyCombo = userDefaults.dictionary(forKey: StorageKey.legacyHotKey).flatMap(
            KeyCombo.init(dictionary:)
        )
        return [HotKeyBinding(keyCombo: legacyCombo ?? defaultHotKeyCombo, command: .openLauncher)]
    }

    private func saveHotKeyBindings() {
        guard let data = try? JSONEncoder().encode(hotKeyBindings) else { return }
        userDefaults.set(data, forKey: StorageKey.hotKeyBindings)
    }

    /// Appends a binding that opens the launcher on a combination that no
    /// binding holds. Does nothing when every suggestion is taken.
    func addHotKeyBinding() {
        guard let keyCombo = HotKeyBindingValidator.suggestFreeCombo(among: hotKeyBindings) else {
            return
        }
        hotKeyBindings.append(HotKeyBinding(keyCombo: keyCombo, command: .openLauncher))
    }

    func removeHotKeyBinding(id: UUID) {
        hotKeyBindings.removeAll { $0.id == id }
    }

    func updateCommand(_ command: HotKeyCommand, forBindingID id: UUID) {
        guard let index = hotKeyBindings.firstIndex(where: { $0.id == id }) else { return }
        hotKeyBindings[index].command = command
    }

    /// Sets the combination of a binding. Returns false and changes nothing
    /// when another binding already holds it.
    @discardableResult
    func assignKeyCombo(
        _ keyCombo: KeyCombo,
        modifierSides: ModifierSides = ModifierSides(),
        toBindingID id: UUID
    ) -> Bool {
        guard
            HotKeyBindingValidator.isAvailable(
                keyCombo,
                modifierSides: modifierSides,
                forBindingID: id,
                among: hotKeyBindings
            ),
            let index = hotKeyBindings.firstIndex(where: { $0.id == id })
        else { return false }
        hotKeyBindings[index].keyCombo = keyCombo
        hotKeyBindings[index].modifierSides = modifierSides
        return true
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
        hotKeyBindings = [
            HotKeyBinding(keyCombo: Self.defaultHotKeyCombo, command: .openLauncher)
        ]
        mascotHeadColor = MascotModel.defaultHeadColor
        mascotBodyColor = MascotModel.defaultBodyColor
        repositoryRootPath = Self.defaultRepositoryRootPath
        fileFolderPaths = Self.defaultFileFolderPaths
        shouldShowDockIcon = true
        llmBaseURL = Self.defaultLLMBaseURL
        llmModelName = Self.defaultLLMModelName
    }
}
