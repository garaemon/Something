import Foundation
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
    var command: HotKeyCommand

    init(id: UUID = UUID(), keyCombo: KeyCombo, command: HotKeyCommand) {
        self.id = id
        self.keyCombo = keyCombo
        self.command = command
    }

    private enum CodingKeys: String, CodingKey {
        case id, carbonKeyCode, carbonModifiers, command
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        keyCombo = KeyCombo(
            carbonKeyCode: try container.decode(UInt32.self, forKey: .carbonKeyCode),
            carbonModifiers: try container.decode(UInt32.self, forKey: .carbonModifiers)
        )
        command = try container.decode(HotKeyCommand.self, forKey: .command)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(keyCombo.carbonKeyCode, forKey: .carbonKeyCode)
        try container.encode(keyCombo.carbonModifiers, forKey: .carbonModifiers)
        try container.encode(command, forKey: .command)
    }
}

/// Rules that keep the bindings from clashing.
enum HotKeyBindingValidator {
    /// Combinations offered to a new binding, in order. Control, Option, and
    /// Command together rarely collide with applications.
    static let suggestedCombos: [KeyCombo] = ([.l, .k, .j, .h, .g, .f, .d, .s, .a] as [Key]).map {
        KeyCombo(key: $0, modifiers: [.control, .option, .command])
    }

    /// Returns true when no other binding holds `keyCombo`. A binding never
    /// clashes with itself, so that recording the same key again is harmless.
    static func isAvailable(
        _ keyCombo: KeyCombo,
        forBindingID bindingID: UUID,
        among bindings: [HotKeyBinding]
    ) -> Bool {
        !bindings.contains { $0.id != bindingID && $0.keyCombo == keyCombo }
    }

    /// Returns the first suggested combination that no binding holds, or nil.
    static func suggestFreeCombo(among bindings: [HotKeyBinding]) -> KeyCombo? {
        suggestedCombos.first { combo in !bindings.contains { $0.keyCombo == combo } }
    }
}
