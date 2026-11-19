import HotKey
import XCTest

@testable import Something

final class ModifierSidesTests: XCTestCase {
    func test_should_not_be_sided_by_default() {
        XCTAssertFalse(ModifierSides().isSided)
    }

    func test_should_be_sided_when_one_modifier_has_a_side() {
        XCTAssertTrue(ModifierSides(shift: .right).isSided)
    }

    func test_should_read_held_sides_from_device_bits() {
        let sides = ModifierSides.fromHeldFlags(
            ModifierFlagBits.rightShiftHeld | ModifierFlagBits.leftCommandHeld)

        XCTAssertEqual(sides, ModifierSides(command: .left, shift: .right))
    }

    func test_should_read_either_when_both_sides_are_held() {
        let sides = ModifierSides.fromHeldFlags(
            ModifierFlagBits.rightShiftHeld | ModifierFlagBits.leftShiftHeld)

        XCTAssertEqual(sides, ModifierSides())
    }

    func test_should_describe_right_shift_binding() {
        let binding = HotKeyBinding(
            keyCombo: KeyCombo(key: .e, modifiers: [.shift]),
            modifierSides: ModifierSides(shift: .right),
            command: .openLauncher)

        XCTAssertEqual(binding.shortcutDescription, "Right ⇧E")
    }

    func test_should_describe_unsided_binding_like_key_combo() {
        let keyCombo = KeyCombo(key: .x, modifiers: [.command, .shift])
        let binding = HotKeyBinding(keyCombo: keyCombo, command: .openLauncher)

        XCTAssertEqual(binding.shortcutDescription, keyCombo.description)
    }

    func test_should_describe_mixed_sides() {
        let binding = HotKeyBinding(
            keyCombo: KeyCombo(key: .e, modifiers: [.control, .shift]),
            modifierSides: ModifierSides(control: .left),
            command: .openLauncher)

        XCTAssertEqual(binding.shortcutDescription, "Left ⌃ ⇧E")
    }
}
