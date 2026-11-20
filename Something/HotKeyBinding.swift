import Foundation
import HotKey

/// An action that a global hot key runs.
///
/// A command without data encodes as its plain name, as before applications
/// existed, so that bindings saved earlier keep loading.
enum HotKeyCommand: Codable, Hashable {
    case openLauncher
    case openScratch
    case openSettings
    case openApplication(ApplicationTarget)

    /// The commands that carry no data, in the order of the command picker.
    static let plainCommands: [HotKeyCommand] = [.openLauncher, .openScratch, .openSettings]

    /// The name that the settings window shows in the command picker.
    var title: String {
        switch self {
        case .openLauncher: return "Open Launcher"
        case .openScratch: return "Open Python Scratch"
        case .openSettings: return "Open Settings"
        case .openApplication(let target): return "Open \(target.name)"
        }
    }

    private var plainName: String {
        switch self {
        case .openLauncher: return "openLauncher"
        case .openScratch: return "openScratch"
        case .openSettings: return "openSettings"
        case .openApplication: return "openApplication"
        }
    }

    private enum ApplicationKeys: String, CodingKey {
        case openApplication
    }

    init(from decoder: Decoder) throws {
        if let name = try? decoder.singleValueContainer().decode(String.self) {
            guard let command = Self.plainCommands.first(where: { $0.plainName == name }) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Unknown command")
                )
            }
            self = command
            return
        }
        let container = try decoder.container(keyedBy: ApplicationKeys.self)
        self = .openApplication(
            try container.decode(ApplicationTarget.self, forKey: .openApplication)
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .openApplication(let target):
            var container = encoder.container(keyedBy: ApplicationKeys.self)
            try container.encode(target, forKey: .openApplication)
        case .openLauncher, .openScratch, .openSettings:
            var container = encoder.singleValueContainer()
            try container.encode(plainName)
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
