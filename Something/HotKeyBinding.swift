import AppKit
import HotKey

/// An action that a global hot key runs.
enum HotKeyCommand: String, Codable, CaseIterable, Identifiable {
    case openLauncher
    case openScratch
    case openSettings

    var id: String { rawValue }

    /// The name that the settings window shows in the command picker.
    var title: String {
        switch self {
        case .openLauncher: return "Open Launcher"
        case .openScratch: return "Open Python Scratch"
        case .openSettings: return "Open Settings"
        }
    }
}

/// One global hot key and the command it runs. Stored as JSON, because
/// `KeyCombo` is not `Codable`.
struct HotKeyBinding: Identifiable, Equatable, Codable {
    let id: UUID
    var keyCombo: KeyCombo
    /// The side of each modifier in `keyCombo`. A sided binding runs through the
    /// event tap, because Carbon cannot tell the left key from the right one.
    var modifierSides: ModifierSides
    var command: HotKeyCommand

    init(
        id: UUID = UUID(),
        keyCombo: KeyCombo,
        modifierSides: ModifierSides = ModifierSides(),
        command: HotKeyCommand
    ) {
        self.id = id
        self.keyCombo = keyCombo
        self.modifierSides = modifierSides
        self.command = command
    }

    private enum CodingKeys: String, CodingKey {
        case id, carbonKeyCode, carbonModifiers, modifierSides, command
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        keyCombo = KeyCombo(
            carbonKeyCode: try container.decode(UInt32.self, forKey: .carbonKeyCode),
            carbonModifiers: try container.decode(UInt32.self, forKey: .carbonModifiers)
        )
        // Bindings saved before sides existed have no key and need either side.
        modifierSides =
            try container.decodeIfPresent(ModifierSides.self, forKey: .modifierSides)
            ?? ModifierSides()
        command = try container.decode(HotKeyCommand.self, forKey: .command)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(keyCombo.carbonKeyCode, forKey: .carbonKeyCode)
        try container.encode(keyCombo.carbonModifiers, forKey: .carbonModifiers)
        try container.encode(modifierSides, forKey: .modifierSides)
        try container.encode(command, forKey: .command)
    }

    /// The shortcut as the settings window shows it, such as "Right ⇧E".
    var shortcutDescription: String {
        guard modifierSides.isSided else { return keyCombo.description }
        let modifierSymbols: [(flag: NSEvent.ModifierFlags, symbol: String)] = [
            (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
        ]
        var sidedTokens: [String] = []
        var unsidedSymbols = ""
        for (flag, symbol) in modifierSymbols where keyCombo.modifiers.contains(flag) {
            switch modifierSides.side(of: flag) {
            case .either: unsidedSymbols += symbol
            case .left: sidedTokens.append("Left \(symbol)")
            case .right: sidedTokens.append("Right \(symbol)")
            }
        }
        let separator = unsidedSymbols.isEmpty ? "" : " "
        let keyName = keyCombo.key?.description ?? "?"
        return sidedTokens.joined(separator: " ") + separator + unsidedSymbols + keyName
    }
}

/// Decodes to nil instead of throwing, so that one unreadable entry does not
/// discard the other saved bindings.
struct LossyBinding: Decodable {
    let binding: HotKeyBinding?

    init(from decoder: Decoder) throws {
        binding = try? HotKeyBinding(from: decoder)
    }
}

/// Rules that keep the bindings from clashing.
enum HotKeyBindingValidator {
    /// Combinations offered to a new binding, in order. Control, Option, and
    /// Command together rarely collide with applications.
    static let suggestedCombos: [KeyCombo] = ([.l, .k, .j, .h, .g, .f, .d, .s, .a] as [Key]).map {
        KeyCombo(key: $0, modifiers: [.control, .option, .command])
    }

    /// Returns true when no other binding overlaps `keyCombo` with `modifierSides`. Two
    /// bindings overlap when one key press can trigger both, such as Command + E (either side)
    /// and Left Command + E. A binding never clashes with itself, so that recording the same
    /// key again is harmless.
    static func isAvailable(
        _ keyCombo: KeyCombo,
        modifierSides: ModifierSides = ModifierSides(),
        forBindingID bindingID: UUID,
        among bindings: [HotKeyBinding]
    ) -> Bool {
        !bindings.contains {
            $0.id != bindingID
                && overlaps(keyCombo, modifierSides, $0.keyCombo, $0.modifierSides)
        }
    }

    private static func overlaps(
        _ firstCombo: KeyCombo,
        _ firstSides: ModifierSides,
        _ secondCombo: KeyCombo,
        _ secondSides: ModifierSides
    ) -> Bool {
        guard firstCombo == secondCombo else { return false }
        return ModifierFlagBits.allModifiers.allSatisfy { modifier in
            guard firstCombo.modifiers.contains(modifier.flag) else { return true }
            let firstSide = firstSides.side(of: modifier.flag)
            let secondSide = secondSides.side(of: modifier.flag)
            return firstSide == .either || secondSide == .either || firstSide == secondSide
        }
    }

    /// Returns the first suggested combination that no binding holds, or nil.
    static func suggestFreeCombo(among bindings: [HotKeyBinding]) -> KeyCombo? {
        suggestedCombos.first { combo in
            isAvailable(combo, forBindingID: UUID(), among: bindings)
        }
    }
}
