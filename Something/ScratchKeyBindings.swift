import Foundation

/// A command of the scratch window that a key sequence runs.
enum ScratchCommand: Equatable {
    case runBlockAtCursor
    case runAllBlocks
    case resetInterpreter
}

/// What the scratch window does with one key press.
enum ScratchKeyResolution: Equatable {
    case command(ScratchCommand)
    /// The press starts a sequence, so the window waits for the next key.
    case prefix
    /// The press ends a sequence that names no command, and types nothing.
    case swallowed
    /// The press is not a scratch key, so the text view handles it.
    case passThrough
}

/// Resolves the Emacs-style keys of the scratch window: C-j, C-c C-c, and C-c C-k.
struct ScratchKeyBindings {
    private var isAfterPrefix = false

    /// Returns what to do with a press of `key`, the character without modifiers.
    ///
    /// `isControlOnly` is true when Control is the only modifier held.
    mutating func resolve(key: String, isControlOnly: Bool) -> ScratchKeyResolution {
        if isAfterPrefix {
            isAfterPrefix = false
            switch (key, isControlOnly) {
            case ("c", true): return .command(.runAllBlocks)
            case ("k", true): return .command(.resetInterpreter)
            default: return .swallowed
            }
        }
        switch (key, isControlOnly) {
        case ("j", true): return .command(.runBlockAtCursor)
        case ("c", true):
            isAfterPrefix = true
            return .prefix
        default: return .passThrough
        }
    }
}
