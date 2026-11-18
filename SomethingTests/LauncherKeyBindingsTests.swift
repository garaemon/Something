import SwiftUI
import XCTest

@testable import Something

final class LauncherKeyBindingsTests: XCTestCase {
    func test_should_move_down_on_down_arrow() {
        let command = LauncherKeyBindings.resolve(
            key: .downArrow, isControlPressed: false, isRepeat: false)

        XCTAssertEqual(command, .moveSelection(1))
    }

    func test_should_move_up_on_up_arrow() {
        let command = LauncherKeyBindings.resolve(
            key: .upArrow, isControlPressed: false, isRepeat: false)

        XCTAssertEqual(command, .moveSelection(-1))
    }

    func test_should_keep_moving_down_while_down_arrow_repeats() {
        let command = LauncherKeyBindings.resolve(
            key: .downArrow, isControlPressed: false, isRepeat: true)

        XCTAssertEqual(command, .moveSelection(1))
    }

    func test_should_keep_moving_up_while_up_arrow_repeats() {
        let command = LauncherKeyBindings.resolve(
            key: .upArrow, isControlPressed: false, isRepeat: true)

        XCTAssertEqual(command, .moveSelection(-1))
    }

    func test_should_keep_moving_down_while_control_n_repeats() {
        let command = LauncherKeyBindings.resolve(
            key: KeyEquivalent("n"), isControlPressed: true, isRepeat: true)

        XCTAssertEqual(command, .moveSelection(1))
    }

    func test_should_keep_moving_up_while_control_p_repeats() {
        let command = LauncherKeyBindings.resolve(
            key: KeyEquivalent("p"), isControlPressed: true, isRepeat: true)

        XCTAssertEqual(command, .moveSelection(-1))
    }

    func test_should_dismiss_on_escape() {
        let command = LauncherKeyBindings.resolve(
            key: .escape, isControlPressed: false, isRepeat: false)

        XCTAssertEqual(command, .dismiss)
    }

    func test_should_dismiss_on_control_g() {
        let command = LauncherKeyBindings.resolve(
            key: KeyEquivalent("g"), isControlPressed: true, isRepeat: false)

        XCTAssertEqual(command, .dismiss)
    }

    func test_should_swallow_escape_repeat_instead_of_dismissing_again() {
        let command = LauncherKeyBindings.resolve(
            key: .escape, isControlPressed: false, isRepeat: true)

        XCTAssertEqual(command, .swallow)
    }

    func test_should_swallow_control_g_repeat_instead_of_dismissing_again() {
        let command = LauncherKeyBindings.resolve(
            key: KeyEquivalent("g"), isControlPressed: true, isRepeat: true)

        XCTAssertEqual(command, .swallow)
    }

    func test_should_ignore_n_without_control() {
        let command = LauncherKeyBindings.resolve(
            key: KeyEquivalent("n"), isControlPressed: false, isRepeat: false)

        XCTAssertNil(command)
    }

    func test_should_capture_task_on_command_return() {
        let command = LauncherKeyBindings.resolve(
            key: .return, isControlPressed: false, isCommandPressed: true, isRepeat: false)

        XCTAssertEqual(command, .captureTask)
    }

    func test_should_swallow_repeat_of_command_return() {
        let command = LauncherKeyBindings.resolve(
            key: .return, isControlPressed: false, isCommandPressed: true, isRepeat: true)

        XCTAssertEqual(command, .swallow)
    }

    func test_should_leave_plain_return_to_query_field() {
        let command = LauncherKeyBindings.resolve(
            key: .return, isControlPressed: false, isCommandPressed: false, isRepeat: false)

        XCTAssertNil(command)
    }
}
