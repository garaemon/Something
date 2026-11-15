import AppKit
import HotKey

/// Turns a recorded key press into a global hot key.
enum HotKeyRecording {
    /// The modifiers that Carbon can register. Caps Lock and Fn are not among them.
    private static let registrableModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
    /// A hot key needs one of these, because Shift alone or no modifier would
    /// swallow ordinary typing in every application.
    private static let requiredModifiers: NSEvent.ModifierFlags = [.command, .option, .control]

    /// Returns the hot key for a key press, or nil when the press lacks Command,
    /// Option, or Control.
    static func makeKeyCombo(carbonKeyCode: UInt32, modifierFlags: NSEvent.ModifierFlags) -> KeyCombo? {
        let modifiers = modifierFlags.intersection(registrableModifiers)
        guard !modifiers.isDisjoint(with: requiredModifiers) else { return nil }
        return KeyCombo(carbonKeyCode: carbonKeyCode, carbonModifiers: modifiers.carbonFlags)
    }
}
