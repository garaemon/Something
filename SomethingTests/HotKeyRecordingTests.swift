import AppKit
import HotKey
import XCTest

@testable import Something

final class HotKeyRecordingTests: XCTestCase {
    func test_should_accept_key_with_command_modifier() {
        let keyCombo = HotKeyRecording.makeKeyCombo(
            carbonKeyCode: Key.k.carbonKeyCode, modifierFlags: [.command])

        XCTAssertEqual(keyCombo, KeyCombo(key: .k, modifiers: [.command]))
    }

    // A bare letter would fire on every keystroke typed into any application.
    func test_should_reject_key_without_modifier() {
        let keyCombo = HotKeyRecording.makeKeyCombo(carbonKeyCode: Key.k.carbonKeyCode, modifierFlags: [])

        XCTAssertNil(keyCombo)
    }

    func test_should_reject_key_with_only_shift() {
        let keyCombo = HotKeyRecording.makeKeyCombo(
            carbonKeyCode: Key.k.carbonKeyCode, modifierFlags: [.shift])

        XCTAssertNil(keyCombo)
    }

    func test_should_drop_modifiers_that_carbon_cannot_register() {
        let keyCombo = HotKeyRecording.makeKeyCombo(
            carbonKeyCode: Key.k.carbonKeyCode, modifierFlags: [.control, .capsLock, .function])

        XCTAssertEqual(keyCombo, KeyCombo(key: .k, modifiers: [.control]))
    }
}
