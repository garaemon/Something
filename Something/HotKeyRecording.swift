import AppKit
import HotKey

/// A recorded key press: the combination and the side of each modifier.
struct RecordedShortcut: Equatable {
    let keyCombo: KeyCombo
    let modifierSides: ModifierSides
}

/// Turns a recorded key press into a global hot key.
enum HotKeyRecording {
    /// The modifiers that Carbon can register. Caps Lock and Fn are not among them.
    private static let registrableModifiers: NSEvent.ModifierFlags = [
        .command, .option, .control, .shift,
    ]

    /// Returns the shortcut for a key press. With `keepsSides`, each modifier
    /// keeps the side that was held, read from the device-dependent bits of
    /// `modifierFlags.rawValue`. Returns nil for a press without any modifier,
    /// which would swallow ordinary typing in every application. Shift alone
    /// is accepted, so a binding such as Shift + E takes over that capital
    /// letter unless it keeps only one side.
    static func makeShortcut(
        carbonKeyCode: UInt32,
        modifierFlags: NSEvent.ModifierFlags,
        keepsSides: Bool
    ) -> RecordedShortcut? {
        let modifiers = modifierFlags.intersection(registrableModifiers)
        guard !modifiers.isEmpty else { return nil }
        // A stale device bit of a modifier outside the combination must not make
        // the shortcut sided, so only the held modifiers keep their side.
        let heldSides =
            keepsSides
            ? ModifierSides.readHeldSides(fromFlags: UInt64(modifierFlags.rawValue))
                .restricted(to: modifiers)
            : ModifierSides()
        let keyCombo = KeyCombo(
            carbonKeyCode: carbonKeyCode,
            carbonModifiers: modifiers.carbonFlags
        )
        return RecordedShortcut(keyCombo: keyCombo, modifierSides: heldSides)
    }
}
