import XCTest

@testable import Something

final class ApplicationHotKeyPlannerTests: XCTestCase {
    func test_should_launch_when_application_is_not_running() {
        let action = ApplicationHotKeyPlanner.plan(
            isRunning: false, isFrontmost: false, windowCount: 0)

        XCTAssertEqual(action, .launch)
    }

    func test_should_activate_when_running_in_background() {
        let action = ApplicationHotKeyPlanner.plan(
            isRunning: true, isFrontmost: false, windowCount: 3)

        XCTAssertEqual(action, .activate)
    }

    func test_should_raise_rearmost_window_when_frontmost_with_several_windows() {
        let action = ApplicationHotKeyPlanner.plan(
            isRunning: true, isFrontmost: true, windowCount: 3)

        XCTAssertEqual(action, .raiseWindow(index: 2))
    }

    func test_should_activate_when_frontmost_with_one_window() {
        let action = ApplicationHotKeyPlanner.plan(
            isRunning: true, isFrontmost: true, windowCount: 1)

        XCTAssertEqual(action, .activate)
    }

    func test_should_activate_when_frontmost_without_windows() {
        let action = ApplicationHotKeyPlanner.plan(
            isRunning: true, isFrontmost: true, windowCount: 0)

        XCTAssertEqual(action, .activate)
    }
}
