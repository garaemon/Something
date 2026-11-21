import XCTest

@testable import Something

@MainActor
final class AddTaskSourceTests: XCTestCase {
    func test_should_list_nothing_for_empty_query() {
        let source = AddTaskSource(captureTask: { _ in })

        XCTAssertTrue(source.makeCandidates(matching: "  ").isEmpty)
    }

    func test_should_list_add_task_row_with_query() {
        let source = AddTaskSource(captureTask: { _ in })

        let candidate = source.makeCandidates(matching: "buy milk").first

        XCTAssertEqual(candidate?.name, "Add task: buy milk")
        XCTAssertEqual(candidate?.kind, .task)
    }

    func test_should_capture_trimmed_query_on_default_action() {
        var capturedTitle: String?
        let source = AddTaskSource(captureTask: { capturedTitle = $0 })

        source.makeCandidates(matching: " buy milk ").first?.defaultAction?.perform()

        XCTAssertEqual(capturedTitle, "buy milk")
    }

    func test_should_capture_from_any_row_with_capture_key() {
        var capturedTitle: String?
        let viewModel = LauncherViewModel(sources: [
            WebSearchSource(engines: [.google], openURL: { _ in }),
            AddTaskSource(captureTask: { capturedTitle = $0 }),
        ])
        viewModel.query = "buy milk"

        let didCapture = viewModel.activateTaskCapture()

        XCTAssertTrue(didCapture)
        XCTAssertEqual(capturedTitle, "buy milk")
    }

    func test_should_not_capture_for_empty_query() {
        let viewModel = LauncherViewModel(sources: [AddTaskSource(captureTask: { _ in })])

        XCTAssertFalse(viewModel.activateTaskCapture())
    }

    func test_should_list_add_task_after_web_searches() {
        let viewModel = LauncherViewModel(sources: [
            WebSearchSource(engines: [.google], openURL: { _ in }),
            AddTaskSource(captureTask: { _ in }),
        ])

        viewModel.query = "x"

        XCTAssertEqual(viewModel.candidates.last?.name, "Add task: x")
    }
}
