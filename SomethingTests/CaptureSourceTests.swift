import XCTest

@testable import Something

final class CaptureSourceTests: XCTestCase {
    private func makeSource(
        record: @escaping (CaptureCommand) -> Void = { _ in }
    ) -> CaptureSource {
        CaptureSource(startCapture: record)
    }

    func test_should_list_record_screen_for_record_query() {
        let names = makeSource().makeCandidates(matching: "record").map(\.name)

        XCTAssertEqual(names, ["Record Screen"])
    }

    func test_should_list_both_clipboard_captures_for_capture_query() {
        let names = makeSource().makeCandidates(matching: "capture").map(\.name)

        XCTAssertEqual(names, ["Capture Area to Clipboard", "Capture Window to Clipboard"])
    }

    func test_should_list_nothing_for_empty_query() {
        XCTAssertTrue(makeSource().makeCandidates(matching: "").isEmpty)
    }

    func test_should_list_nothing_for_unrelated_query() {
        XCTAssertTrue(makeSource().makeCandidates(matching: "safari").isEmpty)
    }

    func test_should_tag_candidates_as_capture() {
        let kinds = makeSource().makeCandidates(matching: "capture").map(\.kind)

        XCTAssertEqual(kinds, [.capture, .capture])
    }

    func test_should_open_screenshot_app_for_record_screen() {
        var commands: [CaptureCommand] = []
        let source = makeSource(record: { commands.append($0) })

        source.makeCandidates(matching: "record").first?.defaultAction?.perform()

        XCTAssertEqual(
            commands,
            [.openApplication(URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app"))]
        )
    }

    func test_should_run_interactive_area_capture_to_clipboard() {
        var commands: [CaptureCommand] = []
        let source = makeSource(record: { commands.append($0) })

        source.makeCandidates(matching: "area").first?.defaultAction?.perform()

        XCTAssertEqual(commands, [.runProcess(path: "/usr/sbin/screencapture", arguments: ["-ic"])])
    }

    func test_should_run_interactive_window_capture_to_clipboard() {
        var commands: [CaptureCommand] = []
        let source = makeSource(record: { commands.append($0) })

        source.makeCandidates(matching: "window").first?.defaultAction?.perform()

        XCTAssertEqual(
            commands, [.runProcess(path: "/usr/sbin/screencapture", arguments: ["-iwc"])])
    }
}
