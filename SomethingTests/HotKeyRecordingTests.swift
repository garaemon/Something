import AppKit
import HotKey
import XCTest

@testable import Something

final class HotKeyRecordingTests: XCTestCase {
    func test_should_accept_key_with_command_modifier() {
        let keyCombo = HotKeyRecording.makeShortcut(
            carbonKeyCode: Key.k.carbonKeyCode, modifierFlags: [.command], keepsSides: false)?.keyCombo

        XCTAssertEqual(keyCombo, KeyCombo(key: .k, modifiers: [.command]))
    }

    // A bare letter would fire on every keystroke typed into any application.
    func test_should_reject_key_without_modifier() {
        let keyCombo = HotKeyRecording.makeShortcut(
            carbonKeyCode: Key.k.carbonKeyCode, modifierFlags: [], keepsSides: false)?.keyCombo

        XCTAssertNil(keyCombo)
    }

    func test_should_reject_key_with_only_shift() {
        let keyCombo = HotKeyRecording.makeShortcut(
            carbonKeyCode: Key.k.carbonKeyCode, modifierFlags: [.shift], keepsSides: false)?.keyCombo

        XCTAssertNil(keyCombo)
    }

    func test_should_drop_modifiers_that_carbon_cannot_register() {
        let keyCombo = HotKeyRecording.makeShortcut(
            carbonKeyCode: Key.k.carbonKeyCode, modifierFlags: [.control, .capsLock, .function], keepsSides: false)?.keyCombo

        XCTAssertEqual(keyCombo, KeyCombo(key: .k, modifiers: [.control]))
    }
}

final class HotKeyRecordingSidesTests: XCTestCase {
    private func makeShortcut(
        _ flags: NSEvent.ModifierFlags,
        keepsSides: Bool = true
    ) -> RecordedShortcut? {
        HotKeyRecording.makeShortcut(
            carbonKeyCode: Key.e.carbonKeyCode, modifierFlags: flags, keepsSides: keepsSides)
    }

    private func makeFlags(_ modifiers: NSEvent.ModifierFlags, deviceBits: UInt64)
        -> NSEvent.ModifierFlags
    {
        NSEvent.ModifierFlags(rawValue: modifiers.rawValue | UInt(deviceBits))
    }

    func test_should_keep_right_side_of_held_modifier() {
        let flags = makeFlags([.command, .shift], deviceBits: ModifierFlagBits.rightShiftHeld
            | ModifierFlagBits.leftCommandHeld)

        let shortcut = makeShortcut(flags)

        XCTAssertEqual(shortcut?.keyCombo, KeyCombo(key: .e, modifiers: [.command, .shift]))
        XCTAssertEqual(shortcut?.modifierSides, ModifierSides(command: .left, shift: .right))
    }

    func test_should_drop_sides_when_not_asked_to_keep_them() {
        let flags = makeFlags([.command, .shift], deviceBits: ModifierFlagBits.rightShiftHeld)

        XCTAssertEqual(makeShortcut(flags, keepsSides: false)?.modifierSides, ModifierSides())
    }

    func test_should_accept_right_shift_alone_because_left_shift_keeps_typing() {
        let flags = makeFlags([.shift], deviceBits: ModifierFlagBits.rightShiftHeld)

        XCTAssertEqual(makeShortcut(flags)?.modifierSides, ModifierSides(shift: .right))
    }

    func test_should_ignore_stale_side_bit_of_modifier_outside_the_combination() {
        let flags = makeFlags(
            [.shift], deviceBits: ModifierFlagBits.rightShiftHeld | ModifierFlagBits.leftCommandHeld)

        XCTAssertEqual(makeShortcut(flags)?.modifierSides, ModifierSides(shift: .right))
        XCTAssertNil(makeShortcut(makeFlags([.shift], deviceBits: ModifierFlagBits.leftCommandHeld)))
    }

    func test_should_reject_shift_alone_when_sides_are_not_kept() {
        let flags = makeFlags([.shift], deviceBits: ModifierFlagBits.rightShiftHeld)

        XCTAssertNil(makeShortcut(flags, keepsSides: false))
    }

    func test_should_reject_shift_alone_when_both_sides_are_held() {
        let flags = makeFlags(
            [.shift], deviceBits: ModifierFlagBits.rightShiftHeld | ModifierFlagBits.leftShiftHeld)

        XCTAssertNil(makeShortcut(flags))
    }
}
