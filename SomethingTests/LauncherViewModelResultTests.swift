import XCTest

@testable import Something

@MainActor
final class LauncherViewModelResultTests: XCTestCase {
    private func makeViewModel(onLaunch: @escaping () -> Void = {}) -> LauncherViewModel {
        LauncherViewModel(sources: [
            ApplicationSource(
                applications: ["A", "B"].map(makeApplication),
                launchApplication: { _ in onLaunch() })
        ])
    }

    private func makeIdleStream() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream<String, Error>.makeStream().stream
    }

    func test_should_not_show_a_result_initially() {
        XCTAssertNil(makeViewModel().resultPanel)
    }

    func test_should_show_a_loading_result_after_showResult() {
        let viewModel = makeViewModel()

        viewModel.showResult(title: "Translate", stream: makeIdleStream(), actions: [])

        XCTAssertEqual(viewModel.resultPanel?.title, "Translate")
        XCTAssertEqual(viewModel.resultPanel?.state, .loading)
    }

    func test_should_hide_the_result_after_closeResult() {
        let viewModel = makeViewModel()
        viewModel.showResult(title: "Translate", stream: makeIdleStream(), actions: [])

        viewModel.closeResult()

        XCTAssertNil(viewModel.resultPanel)
    }

    func test_should_close_the_result_when_the_query_changes() {
        let viewModel = makeViewModel()
        viewModel.showResult(title: "T", stream: makeIdleStream(), actions: [])

        viewModel.query = "a"

        XCTAssertNil(viewModel.resultPanel)
    }

    func test_should_cancel_the_stream_after_closeResult() async {
        let viewModel = makeViewModel()
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        viewModel.showResult(title: "Translate", stream: stream, actions: [])
        let panel = viewModel.resultPanel

        viewModel.closeResult()
        continuation.yield("late")
        continuation.finish()
        await panel?.waitUntilDone()

        XCTAssertEqual(panel?.state, .idle)
    }

    func test_should_ignore_movement_while_a_result_is_shown() {
        let viewModel = makeViewModel()
        viewModel.showResult(title: "T", stream: makeIdleStream(), actions: [])

        viewModel.moveSelection(by: 1)

        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func test_should_not_activate_a_candidate_while_a_result_is_shown() {
        var didLaunch = false
        let viewModel = makeViewModel(onLaunch: { didLaunch = true })
        viewModel.showResult(title: "T", stream: makeIdleStream(), actions: [])

        let didRun = viewModel.activateSelection()

        XCTAssertFalse(didRun)
        XCTAssertFalse(didLaunch)
    }

    func test_should_cancel_the_previous_result_when_a_new_one_is_shown() async {
        let viewModel = makeViewModel()
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        viewModel.showResult(title: "First", stream: stream, actions: [])
        let firstPanel = viewModel.resultPanel

        viewModel.showResult(title: "Second", stream: makeIdleStream(), actions: [])
        continuation.finish()
        await firstPanel?.waitUntilDone()

        XCTAssertEqual(firstPanel?.state, .idle)
        XCTAssertEqual(viewModel.resultPanel?.title, "Second")
    }

    func test_should_not_show_actions_while_a_result_is_shown() {
        let viewModel = makeViewModel()
        viewModel.showResult(title: "T", stream: makeIdleStream(), actions: [])

        let didShow = viewModel.showActions()

        XCTAssertFalse(didShow)
    }

    func test_should_close_the_action_list_when_a_result_is_shown() {
        let viewModel = makeViewModel()
        viewModel.showActions()

        viewModel.showResult(title: "T", stream: makeIdleStream(), actions: [])

        XCTAssertFalse(viewModel.isShowingActions)
    }
}
