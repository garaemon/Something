import Combine
import Foundation
import HotKey

/// User preferences, saved to `UserDefaults` on every change.
@MainActor
final class AppSettings: ObservableObject {
    static let defaultHotKeyCombo = KeyCombo(key: .x, modifiers: [.command, .shift])

    private enum StorageKey {
        static let hotKey = "hotKey"
        static let mascotHeadColor = "mascotHeadColor"
        static let mascotBodyColor = "mascotBodyColor"
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
    /// True while the settings window waits for a new hot key. The current hot
    /// key must be paused meanwhile, or Carbon takes the press before the window sees it.
    @Published var isRecordingHotKey = false

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let savedHotKey = (userDefaults.dictionary(forKey: StorageKey.hotKey)).flatMap(KeyCombo.init(dictionary:))
        hotKeyCombo = savedHotKey ?? Self.defaultHotKeyCombo
        mascotHeadColor = userDefaults.string(forKey: StorageKey.mascotHeadColor) ?? MascotModel.defaultHeadColor
        mascotBodyColor = userDefaults.string(forKey: StorageKey.mascotBodyColor) ?? MascotModel.defaultBodyColor
    }

    /// The robot painted with the chosen skin colors.
    var mascotModel: MascotModel {
        MascotModel.default.recolored(headColor: mascotHeadColor, bodyColor: mascotBodyColor)
    }

    func resetToDefaults() {
        hotKeyCombo = Self.defaultHotKeyCombo
        mascotHeadColor = MascotModel.defaultHeadColor
        mascotBodyColor = MascotModel.defaultBodyColor
    }
}
