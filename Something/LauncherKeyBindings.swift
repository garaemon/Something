import SwiftUI

/// A launcher action that a key press runs.
enum LauncherKeyCommand: Equatable {
    /// Moves the selection by the given number of rows; negative moves up.
    case moveSelection(Int)
    case dismiss
}

/// Resolves the launcher keys: Up/Down or C-n/C-p move, and Esc or C-g closes.
enum LauncherKeyBindings {
    /// Returns the command for a press of `key`, or nil when the query field
    /// handles the press.
    ///
    /// `isRepeat` is true for the presses that macOS sends while a key is
    /// held. Held movement keys keep moving, but a held Esc closes only once.
    static func resolve(
        key: KeyEquivalent,
        isControlPressed: Bool,
        isRepeat: Bool
    ) -> LauncherKeyCommand? {
        switch (key, isControlPressed) {
        case (.downArrow, _), (KeyEquivalent("n"), true):
            return .moveSelection(1)
        case (.upArrow, _), (KeyEquivalent("p"), true):
            return .moveSelection(-1)
        case (.escape, _), (KeyEquivalent("g"), true):
            return isRepeat ? nil : .dismiss
        default:
            return nil
        }
    }
}
