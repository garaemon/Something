import XCTest

@testable import Something

@MainActor
final class ResultPanelModelTests: XCTestCase {
    private struct StreamFailure: LocalizedError {
        var errorDescription: String? { "network down" }
    }

    private func makeControlledStream() -> (
        stream: AsyncThrowingStream<String, Error>,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        return (stream, continuation)
    }

    private func makeModel() -> ResultPanelModel {
        ResultPanelModel(title: "Proofread", actions: [])
    }

    func test_should_be_idle_before_a_stream_starts() {
        XCTAssertEqual(makeModel().state, .idle)
    }

    func test_should_be_loading_as_soon_as_a_stream_starts() {
        let model = makeModel()
        let controlled = makeControlledStream()

        model.start(stream: controlled.stream)

        XCTAssertEqual(model.state, .loading)
    }

    func test_should_accumulate_chunks_into_the_finished_text() async {
        let model = makeModel()
        let controlled = makeControlledStream()
        model.start(stream: controlled.stream)

        controlled.continuation.yield("Hello, ")
        controlled.continuation.yield("world")
        controlled.continuation.finish()
        await model.waitUntilDone()

        XCTAssertEqual(model.state, .finished("Hello, world"))
    }

    func test_should_show_streaming_text_before_the_stream_ends() async {
        let model = makeModel()
        let controlled = makeControlledStream()
        model.start(stream: controlled.stream)

        controlled.continuation.yield("partial")
        await model.waitUntilText("partial")

        XCTAssertEqual(model.state, .streaming("partial"))
        controlled.continuation.finish()
    }

    func test_should_finish_with_empty_text_for_an_empty_stream() async {
        let model = makeModel()
        let controlled = makeControlledStream()
        model.start(stream: controlled.stream)

        controlled.continuation.finish()
        await model.waitUntilDone()

        XCTAssertEqual(model.state, .finished(""))
    }

    func test_should_fail_with_the_error_message_when_the_stream_throws() async {
        let model = makeModel()
        let controlled = makeControlledStream()
        model.start(stream: controlled.stream)

        controlled.continuation.yield("partial")
        controlled.continuation.finish(throwing: StreamFailure())
        await model.waitUntilDone()

        XCTAssertEqual(model.state, .failed("network down"))
    }

    func test_should_return_to_idle_when_cancelled() async {
        let model = makeModel()
        let controlled = makeControlledStream()
        model.start(stream: controlled.stream)

        model.cancel()
        controlled.continuation.yield("late")
        controlled.continuation.finish()
        await model.waitUntilDone()

        XCTAssertEqual(model.state, .idle)
    }

    func test_should_replace_the_previous_stream_when_started_again() async {
        let model = makeModel()
        let first = makeControlledStream()
        let second = makeControlledStream()
        model.start(stream: first.stream)

        model.start(stream: second.stream)
        first.continuation.yield("stale")
        first.continuation.finish()
        second.continuation.yield("fresh")
        second.continuation.finish()
        await model.waitUntilDone()

        XCTAssertEqual(model.state, .finished("fresh"))
    }

    func test_should_expose_text_for_streaming_and_finished_states_only() {
        XCTAssertNil(ResultPanelState.loading.text)
        XCTAssertNil(ResultPanelState.failed("x").text)
        XCTAssertEqual(ResultPanelState.streaming("a").text, "a")
        XCTAssertEqual(ResultPanelState.finished("b").text, "b")
    }

    func test_should_pass_the_current_text_to_an_action() async {
        var received: String?
        let action = ResultAction(title: "Copy", perform: { received = $0 })
        let model = ResultPanelModel(title: "T", actions: [action])
        let controlled = makeControlledStream()
        model.start(stream: controlled.stream)
        controlled.continuation.yield("body")
        controlled.continuation.finish()
        await model.waitUntilDone()

        model.perform(action)

        XCTAssertEqual(received, "body")
    }

    func test_should_not_run_an_action_without_text() {
        var didRun = false
        let action = ResultAction(title: "Copy", perform: { _ in didRun = true })
        let model = ResultPanelModel(title: "T", actions: [action])

        model.perform(action)

        XCTAssertFalse(didRun)
    }
}
