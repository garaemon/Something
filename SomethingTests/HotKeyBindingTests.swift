import HotKey
import XCTest

@testable import Something

final class HotKeyBindingTests: XCTestCase {
    private let comboA = KeyCombo(key: .a, modifiers: [.command, .shift])
    private let comboB = KeyCombo(key: .b, modifiers: [.command, .shift])

    func test_should_round_trip_binding_through_json() throws {
        let binding = HotKeyBinding(keyCombo: comboA, command: .openScratch)

        let data = try JSONEncoder().encode(binding)
        let decoded = try JSONDecoder().decode(HotKeyBinding.self, from: data)

        XCTAssertEqual(decoded, binding)
    }

    func test_should_accept_unbound_combo() {
        let existing = HotKeyBinding(keyCombo: comboA, command: .openLauncher)

        let isAvailable = HotKeyBindingValidator.isAvailable(
            comboB, forBindingID: UUID(), among: [existing])

        XCTAssertTrue(isAvailable)
    }

    func test_should_reject_combo_bound_by_another_binding() {
        let existing = HotKeyBinding(keyCombo: comboA, command: .openLauncher)

        let isAvailable = HotKeyBindingValidator.isAvailable(
            comboA, forBindingID: UUID(), among: [existing])

        XCTAssertFalse(isAvailable)
    }

    func test_should_accept_combo_that_only_the_same_binding_holds() {
        let existing = HotKeyBinding(keyCombo: comboA, command: .openLauncher)

        let isAvailable = HotKeyBindingValidator.isAvailable(
            comboA, forBindingID: existing.id, among: [existing])

        XCTAssertTrue(isAvailable)
    }

    func test_should_pick_first_free_combo_for_new_binding() {
        let taken = HotKeyBindingValidator.suggestedCombos[0]
        let existing = HotKeyBinding(keyCombo: taken, command: .openLauncher)

        let suggestion = HotKeyBindingValidator.suggestFreeCombo(among: [existing])

        XCTAssertEqual(suggestion, HotKeyBindingValidator.suggestedCombos[1])
    }
}
