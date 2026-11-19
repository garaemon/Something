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
    /// A hot key needs one of these, because Shift alone or no modifier would
    /// swallow ordinary typing in every application.
    private static let requiredModifiers: NSEvent.ModifierFlags = [.command, .option, .control]

    /// Returns the shortcut for a key press. With `keepsSides`, each modifier
    /// keeps the side that was held, read from the device-dependent bits of
    /// `modifierFlags.rawValue`. A press that holds a sided modifier may use
    /// Shift alone, such as Right Shift + E, because the left Shift keeps
    /// typing. Otherwise the press needs Command, Option, or Control.
    static func makeShortcut(
        carbonKeyCode: UInt32,
        modifierFlags: NSEvent.ModifierFlags,
        keepsSides: Bool
    ) -> RecordedShortcut? {
        // A stale device bit of a modifier outside the combination must not make
        // the shortcut sided, so only the held modifiers keep their side.
        let heldSides =
            keepsSides
            ? ModifierSides.fromHeldFlags(UInt64(modifierFlags.rawValue))
                .restricted(to: modifierFlags.intersection(registrableModifiers))
            : ModifierSides()
        guard
            let keyCombo = makeKeyCombo(
                carbonKeyCode: carbonKeyCode,
                modifierFlags: modifierFlags,
                isSided: heldSides.isSided
            )
        else { return nil }
        return RecordedShortcut(keyCombo: keyCombo, modifierSides: heldSides)
    }

    private static func makeKeyCombo(
        carbonKeyCode: UInt32,
        modifierFlags: NSEvent.ModifierFlags,
        isSided: Bool
    ) -> KeyCombo? {
        let modifiers = modifierFlags.intersection(registrableModifiers)
        let hasRequiredModifier = !modifiers.isDisjoint(with: requiredModifiers)
        guard hasRequiredModifier || (isSided && !modifiers.isEmpty) else { return nil }
        return KeyCombo(carbonKeyCode: carbonKeyCode, carbonModifiers: modifiers.carbonFlags)
    }
}
