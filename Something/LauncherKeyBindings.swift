import SwiftUI

/// A launcher action that a key press runs.
enum LauncherKeyCommand: Equatable {
    /// Moves the selection by the given number of rows; negative moves up.
    case moveSelection(Int)
    /// Closes the launcher, or leaves the action list when it is open.
    case dismiss
    /// Lists the actions of the highlighted row.
    case showActions
    /// Consumes the press without an action, so that the query field never
    /// sees it.
    case swallow
}

/// Resolves the launcher keys: Up/Down or C-n/C-p move, Tab or C-z lists the
/// actions, and Esc or C-g closes.
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
        isRepeat: Bool
    ) -> LauncherKeyCommand? {
        switch (key, isControlPressed) {
        case (.downArrow, _), (KeyEquivalent("n"), true):
            return .moveSelection(1)
        case (.upArrow, _), (KeyEquivalent("p"), true):
            return .moveSelection(-1)
        case (.tab, _), (KeyEquivalent("z"), true):
            return .showActions
        case (.escape, _), (KeyEquivalent("g"), true):
            return isRepeat ? .swallow : .dismiss
        default:
            return nil
        }
    }
}
