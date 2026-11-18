import SwiftUI

/// A launcher action that a key press runs.
enum LauncherKeyCommand: Equatable {
    /// Moves the selection by the given number of rows; negative moves up.
    case moveSelection(Int)
    case dismiss
    /// Captures the query as a task from any row.
    case captureTask
    /// Consumes the press without an action, so that the query field never
    /// sees it.
    case swallow
}

/// Resolves the launcher keys: Up/Down or C-n/C-p move, Esc or C-g closes, and
/// Command-Return captures the query as a task.
enum LauncherKeyBindings {
    /// Returns the command for a press of `key`, or nil when the query field
    /// handles the press.
    ///
    /// `isRepeat` is true for the presses that macOS sends while a key is
    /// held. Held movement keys keep moving, but a held Esc closes only once
    /// and swallows its repeats. NSTextView would otherwise take a repeated
    /// Esc as `cancelOperation:` and open the completion list.
    static func resolve(
        key: KeyEquivalent,
        isControlPressed: Bool,
        isCommandPressed: Bool = false,
        isRepeat: Bool
    ) -> LauncherKeyCommand? {
        if key == .return && isCommandPressed {
            return isRepeat ? .swallow : .captureTask
        }
        switch (key, isControlPressed) {
        case (.downArrow, _), (KeyEquivalent("n"), true):
            return .moveSelection(1)
        case (.upArrow, _), (KeyEquivalent("p"), true):
            return .moveSelection(-1)
        case (.escape, _), (KeyEquivalent("g"), true):
            return isRepeat ? .swallow : .dismiss
        default:
            return nil
        }
    }
}
