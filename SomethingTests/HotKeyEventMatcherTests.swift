import HotKey
import XCTest

@testable import Something

final class HotKeyEventMatcherTests: XCTestCase {
    private let shiftE = KeyCombo(key: .e, modifiers: [.shift])
    private let commandShiftE = KeyCombo(key: .e, modifiers: [.command, .shift])
    private let rightShift = ModifierSides(shift: .right)
    private let leftShift = ModifierSides(shift: .left)

    private func matches(
        _ keyCombo: KeyCombo,
        _ sides: ModifierSides,
        keyCode: UInt32 = Key.e.carbonKeyCode,
        flags: UInt64
    ) -> Bool {
        HotKeyEventMatcher.matches(keyCode: keyCode, flags: flags, keyCombo: keyCombo, sides: sides)
    }

    func test_should_match_right_shift_when_right_shift_is_held() {
        XCTAssertTrue(matches(shiftE, rightShift, flags: ModifierFlagBits.rightShiftHeld))
    }

    func test_should_not_match_right_shift_binding_when_left_shift_is_held() {
        XCTAssertFalse(matches(shiftE, rightShift, flags: ModifierFlagBits.leftShiftHeld))
    }

    func test_should_match_left_shift_when_left_shift_is_held() {
        XCTAssertTrue(matches(shiftE, leftShift, flags: ModifierFlagBits.leftShiftHeld))
    }

    func test_should_not_match_sided_binding_when_both_sides_are_held() {
        let bothShifts = ModifierFlagBits.leftShiftHeld | ModifierFlagBits.rightShiftHeld

        XCTAssertFalse(matches(shiftE, rightShift, flags: bothShifts))
    }

    func test_should_match_either_side_when_binding_has_no_side() {
        XCTAssertTrue(matches(shiftE, ModifierSides(), flags: ModifierFlagBits.leftShiftHeld))
        XCTAssertTrue(matches(shiftE, ModifierSides(), flags: ModifierFlagBits.rightShiftHeld))
    }

    func test_should_match_either_side_by_generic_flag_without_device_bits() {
        XCTAssertTrue(matches(shiftE, ModifierSides(), flags: ModifierFlagBits.genericShift))
    }

    func test_should_not_match_sided_binding_by_generic_flag_without_device_bits() {
        XCTAssertFalse(matches(shiftE, rightShift, flags: ModifierFlagBits.genericShift))
    }

    func test_should_not_match_other_key_code() {
        XCTAssertFalse(
            matches(
                shiftE, rightShift, keyCode: Key.f.carbonKeyCode,
                flags: ModifierFlagBits.rightShiftHeld))
    }

    func test_should_not_match_when_required_modifier_is_missing() {
        XCTAssertFalse(matches(shiftE, rightShift, flags: 0))
    }

    func test_should_not_match_when_extra_modifier_is_held() {
        let shiftAndCommand =
            ModifierFlagBits.rightShiftHeld | ModifierFlagBits.leftCommandHeld
            | ModifierFlagBits.genericCommand

        XCTAssertFalse(matches(shiftE, rightShift, flags: shiftAndCommand))
    }

    func test_should_ignore_stale_device_bit_of_modifier_outside_the_combination() {
        let staleCommand = ModifierFlagBits.rightShiftHeld | ModifierFlagBits.leftCommandHeld

        XCTAssertTrue(matches(shiftE, rightShift, flags: staleCommand))
    }

    func test_should_match_mixed_sides_for_two_modifiers() {
        let sides = ModifierSides(command: .left, shift: .right)
        let flags = ModifierFlagBits.leftCommandHeld | ModifierFlagBits.rightShiftHeld

        XCTAssertTrue(matches(commandShiftE, sides, flags: flags))
    }

    func test_should_not_match_mixed_sides_when_sides_are_swapped() {
        let sides = ModifierSides(command: .left, shift: .right)
        let flags = ModifierFlagBits.rightCommandHeld | ModifierFlagBits.leftShiftHeld

        XCTAssertFalse(matches(commandShiftE, sides, flags: flags))
    }

    func test_should_ignore_caps_lock_and_function_bits() {
        let flags =
            ModifierFlagBits.rightShiftHeld | ModifierFlagBits.capsLock
            | ModifierFlagBits.function

        XCTAssertTrue(matches(shiftE, rightShift, flags: flags))
    }

    func test_should_tell_right_option_apart_from_left_option() {
        let optionE = KeyCombo(key: .e, modifiers: [.option])
        let sides = ModifierSides(option: .right)

        XCTAssertTrue(matches(optionE, sides, flags: ModifierFlagBits.rightOptionHeld))
        XCTAssertFalse(matches(optionE, sides, flags: ModifierFlagBits.leftOptionHeld))
    }

    func test_should_tell_right_control_apart_from_left_control() {
        let controlE = KeyCombo(key: .e, modifiers: [.control])
        let sides = ModifierSides(control: .right)

        XCTAssertTrue(matches(controlE, sides, flags: ModifierFlagBits.rightControlHeld))
        XCTAssertFalse(matches(controlE, sides, flags: ModifierFlagBits.leftControlHeld))
    }
}
