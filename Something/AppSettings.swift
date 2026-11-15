import Combine
import Foundation
import HotKey

/// User preferences, saved to `UserDefaults` on every change.
@MainActor
final class AppSettings: ObservableObject {
    static let defaultHotKeyCombo = KeyCombo(key: .x, modifiers: [.command, .shift])

    private enum StorageKey {
        static let hotKey = "hotKey"
    }

    @Published var hotKeyCombo: KeyCombo {
        didSet { userDefaults.set(hotKeyCombo.dictionary, forKey: StorageKey.hotKey) }
    }
    /// True while the settings window waits for a new hot key. The current hot
    /// key must be paused meanwhile, or Carbon takes the press before the window sees it.
    @Published var isRecordingHotKey = false

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let savedHotKey = (userDefaults.dictionary(forKey: StorageKey.hotKey)).flatMap(KeyCombo.init(dictionary:))
        hotKeyCombo = savedHotKey ?? Self.defaultHotKeyCombo
    }

    func resetToDefaults() {
        hotKeyCombo = Self.defaultHotKeyCombo
    }
}
