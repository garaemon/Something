import HotKey
import XCTest

@testable import Something

@MainActor
final class HotKeyCommandCodingTests: XCTestCase {
    private let combo = KeyCombo(key: .a, modifiers: [.command, .shift])

    func test_should_round_trip_open_application_command() throws {
        let target = ApplicationTarget(
            path: "/Applications/Safari.app", bundleIdentifier: "com.apple.Safari")
        let binding = HotKeyBinding(keyCombo: combo, command: .openApplication(target))

        let data = try JSONEncoder().encode(binding)
        let decoded = try JSONDecoder().decode(HotKeyBinding.self, from: data)

        XCTAssertEqual(decoded, binding)
    }

    func test_should_decode_command_saved_as_plain_string() throws {
        let json = """
            {"id":"\(UUID().uuidString)","carbonKeyCode":0,"carbonModifiers":256,\
            "command":"openScratch"}
            """

        let decoded = try JSONDecoder().decode(HotKeyBinding.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.command, .openScratch)
    }

    func test_should_keep_plain_string_shape_for_commands_without_data() throws {
        let data = try JSONEncoder().encode(HotKeyCommand.openSettings)

        XCTAssertEqual(String(data: data, encoding: .utf8), "\"openSettings\"")
    }

    func test_should_load_previously_saved_bindings_from_user_defaults() throws {
        let suiteName = "HotKeyCommandCodingTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let savedJSON = """
            [{"id":"\(UUID().uuidString)","carbonKeyCode":7,"carbonModifiers":256,\
            "command":"openLauncher"}]
            """
        userDefaults.set(Data(savedJSON.utf8), forKey: "hotKeyBindings")

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.hotKeyBindings.map(\.command), [.openLauncher])
    }

    func test_should_name_application_after_bundle_file() {
        let target = ApplicationTarget(path: "/Applications/Safari.app", bundleIdentifier: nil)

        XCTAssertEqual(target.name, "Safari")
    }
}
