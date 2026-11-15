import XCTest

@testable import Something

final class MascotStateTests: XCTestCase {
    func test_should_appear_when_window_just_opened_with_empty_query() {
        XCTAssertEqual(MascotState.derive(query: "", candidateCount: 10, justOpened: true), .appearing)
    }

    func test_should_be_idle_with_empty_query() {
        XCTAssertEqual(MascotState.derive(query: "", candidateCount: 10, justOpened: false), .idle)
    }

    func test_should_type_when_query_has_candidates() {
        XCTAssertEqual(MascotState.derive(query: "saf", candidateCount: 1, justOpened: false), .typing)
    }

    func test_should_type_instead_of_appearing_when_query_is_not_empty() {
        XCTAssertEqual(MascotState.derive(query: "s", candidateCount: 3, justOpened: true), .typing)
    }

    func test_should_report_no_match_when_query_has_no_candidates() {
        XCTAssertEqual(MascotState.derive(query: "zzz", candidateCount: 0, justOpened: false), .noMatch)
    }

    func test_should_show_blinking_cursor_when_idle() {
        XCTAssertEqual(MascotScreen.text(for: .idle, query: "", elapsed: 0.1), "_")
        XCTAssertEqual(MascotScreen.text(for: .idle, query: "", elapsed: 0.4), "")
    }

    func test_should_show_nothing_before_cursor_appears() {
        XCTAssertEqual(MascotScreen.text(for: .appearing, query: "", elapsed: 1.0), "")
        XCTAssertEqual(MascotScreen.text(for: .appearing, query: "", elapsed: 2.6), "_")
    }

    func test_should_show_query_and_cursor_when_typing() {
        XCTAssertEqual(MascotScreen.text(for: .typing, query: "org", elapsed: 0.1), "org_")
    }

    func test_should_keep_cursor_solid_right_after_a_keystroke() {
        XCTAssertEqual(MascotScreen.text(for: .typing, query: "o", elapsed: 0.4), "o_")
    }

    func test_should_show_only_the_query_tail_when_it_is_long() {
        XCTAssertEqual(MascotScreen.text(for: .typing, query: "visual studio", elapsed: 0.1), "udio_")
    }

    func test_should_show_question_mark_when_nothing_matches() {
        XCTAssertEqual(MascotScreen.text(for: .noMatch, query: "zzz", elapsed: 0.1), "?")
    }

    func test_should_parse_hex_colors() throws {
        let color = try XCTUnwrap(MascotModel.rgb(hex: "#FF9A4D"))

        XCTAssertEqual(color.red, 1, accuracy: 0.001)
        XCTAssertEqual(color.green, 154.0 / 255, accuracy: 0.001)
        XCTAssertNil(MascotModel.rgb(hex: "orange"))
    }

    func test_should_round_trip_default_model_through_json() throws {
        let data = try JSONEncoder().encode(MascotModel.default)

        XCTAssertEqual(try JSONDecoder().decode(MascotModel.self, from: data), MascotModel.default)
    }

    func test_should_start_off_screen_when_appearing() {
        let pose = MascotChoreography.pose(state: .appearing, elapsed: 0, sinceInput: 9, inputCount: 0)

        XCTAssertEqual(pose.target, MascotChoreography.startPosition, accuracy: 0.001)
        XCTAssertEqual(pose.yaw, -Double.pi / 2, accuracy: 0.001)
    }

    func test_should_rest_at_the_resting_yaw_after_appearing() {
        let pose = MascotChoreography.pose(state: .appearing, elapsed: 3, sinceInput: 9, inputCount: 0)

        XCTAssertEqual(pose.target, 0, accuracy: 0.001)
        XCTAssertEqual(pose.yaw, MascotChoreography.restingYaw, accuracy: 0.001)
    }

    func test_should_kick_and_nod_once_per_query_change() {
        var animator = MascotAnimator()
        var snapshot = MascotSnapshot()
        snapshot.state = .typing
        _ = animator.advance(by: 1.0 / 60, snapshot: snapshot)

        snapshot.query = "a"
        snapshot.inputCount += 1
        let frame = animator.advance(by: 1.0 / 60, snapshot: snapshot)

        XCTAssertEqual(frame.screenText, "a_")
        XCTAssertGreaterThan(frame.headPitch, 0.05)
    }

    func test_should_stay_in_view_while_a_key_repeats() {
        var animator = MascotAnimator()
        var snapshot = MascotSnapshot()
        snapshot.state = .typing
        var maxDistance = 0.0

        // Four seconds of key repeat: one query change on every other frame.
        for frameIndex in 0..<240 {
            if frameIndex % 2 == 0 {
                snapshot.query += "a"
                snapshot.inputCount += 1
            }
            let frame = animator.advance(by: 1.0 / 60, snapshot: snapshot)
            maxDistance = max(maxDistance, abs(frame.position))
        }

        XCTAssertLessThan(maxDistance, 0.5)
    }
}
