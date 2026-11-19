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

    func test_should_round_trip_sided_binding_through_json() throws {
        let binding = HotKeyBinding(
            keyCombo: KeyCombo(key: .e, modifiers: [.shift]),
            modifierSides: ModifierSides(shift: .right),
            command: .openLauncher)

        let data = try JSONEncoder().encode(binding)
        let decoded = try JSONDecoder().decode(HotKeyBinding.self, from: data)

        XCTAssertEqual(decoded.modifierSides, ModifierSides(shift: .right))
    }

    // JSON that the release before sides existed saved.
    func test_should_load_binding_saved_without_sides_as_either_side() throws {
        let id = UUID()
        let json = """
            {"id":"\(id.uuidString)","carbonKeyCode":\(comboA.carbonKeyCode),\
            "carbonModifiers":\(comboA.carbonModifiers),"command":"openScratch"}
            """

        let decoded = try JSONDecoder().decode(HotKeyBinding.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.keyCombo, comboA)
        XCTAssertEqual(decoded.modifierSides, ModifierSides())
        XCTAssertEqual(decoded.command, .openScratch)
    }

    func test_should_accept_same_combo_on_opposite_sides() {
        let existing = HotKeyBinding(
            keyCombo: comboA, modifierSides: ModifierSides(shift: .left), command: .openLauncher)

        let isAvailable = HotKeyBindingValidator.isAvailable(
            comboA, modifierSides: ModifierSides(shift: .right), forBindingID: UUID(),
            among: [existing])

        XCTAssertTrue(isAvailable)
    }

    // One press of Left Shift + Command + A would trigger both bindings.
    func test_should_reject_sided_combo_that_overlaps_either_side_binding() {
        let existing = HotKeyBinding(keyCombo: comboA, command: .openLauncher)

        let isAvailable = HotKeyBindingValidator.isAvailable(
            comboA, modifierSides: ModifierSides(shift: .right), forBindingID: UUID(),
            among: [existing])

        XCTAssertFalse(isAvailable)
    }

    func test_should_reject_same_combo_with_same_sides() {
        let sides = ModifierSides(shift: .right)
        let existing = HotKeyBinding(keyCombo: comboA, modifierSides: sides, command: .openLauncher)

        let isAvailable = HotKeyBindingValidator.isAvailable(
            comboA, modifierSides: sides, forBindingID: UUID(), among: [existing])

        XCTAssertFalse(isAvailable)
    }
}
