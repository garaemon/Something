import AppKit
import XCTest

@testable import Something

// The runner calls Python off the main thread, so the fake guards its records with a lock.
private final class FakePython: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedBlocks: [PythonBlock] = []
    private var recordedResetCount = 0

    var ranBlocks: [PythonBlock] { lock.withLock { recordedBlocks } }
    var resetCount: Int { lock.withLock { recordedResetCount } }

    // Prints the number of the run, so that each result tells which run made it.
    func run(_ block: PythonBlock) -> PythonRunResult {
        lock.withLock {
            recordedBlocks.append(block)
            return PythonRunResult(output: "\(recordedBlocks.count)\n", errorMessage: nil)
        }
    }

    func reset() {
        lock.withLock { recordedResetCount += 1 }
    }
}

@MainActor
final class ScratchRunnerTests: XCTestCase {
    private let python = FakePython()
    private var ranBlocks: [PythonBlock] { python.ranBlocks }
    private var resetCount: Int { python.resetCount }

    private func makeRunner(text: String, cursor: Int) -> (ScratchRunner, NSTextView) {
        let textView = NSTextView()
        textView.string = text
        textView.setSelectedRange(NSRange(location: cursor, length: 0))
        let python = python
        let runner = ScratchRunner(
            textView: textView,
            runPython: { python.run($0) },
            resetPython: { python.reset() }
        )
        return (runner, textView)
    }

    private func perform(_ command: ScratchCommand, on runner: ScratchRunner) {
        let finished = expectation(description: "run finished")
        runner.onRunFinished = { finished.fulfill() }
        runner.perform(command)
        wait(for: [finished], timeout: 5)
    }

    func test_should_insert_result_under_block_at_cursor() {
        let (runner, textView) = makeRunner(text: "x = 1\nx\n\ny = 2", cursor: 0)

        perform(.runBlockAtCursor, on: runner)

        XCTAssertEqual(textView.string, "x = 1\nx\n# => 1\n\ny = 2")
    }

    func test_should_run_last_statement_for_its_value() {
        let (runner, _) = makeRunner(text: "x = 1\nx", cursor: 0)

        perform(.runBlockAtCursor, on: runner)

        XCTAssertEqual(ranBlocks, [PythonBlock(leadingSource: "x = 1", lastStatement: "x")])
    }

    func test_should_replace_previous_result() {
        let (runner, textView) = makeRunner(text: "x\n# => old\n# !! old error\n\ny", cursor: 0)

        perform(.runBlockAtCursor, on: runner)

        XCTAssertEqual(textView.string, "x\n# => 1\n\ny")
    }

    func test_should_append_result_to_block_at_end_of_text() {
        let (runner, textView) = makeRunner(text: "x", cursor: 1)

        perform(.runBlockAtCursor, on: runner)

        XCTAssertEqual(textView.string, "x\n# => 1")
    }

    func test_should_run_block_at_given_line_instead_of_cursor() {
        let (runner, textView) = makeRunner(text: "a\n\nb", cursor: 0)
        let finished = expectation(description: "run finished")
        runner.onRunFinished = { finished.fulfill() }

        runner.runBlock(atLine: 2)
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(textView.string, "a\n\nb\n# => 1")
    }

    func test_should_run_every_block_in_order() {
        let (runner, textView) = makeRunner(text: "a\n\nb", cursor: 0)

        perform(.runAllBlocks, on: runner)

        XCTAssertEqual(textView.string, "a\n# => 1\n\nb\n# => 2")
    }

    func test_should_not_run_anything_from_blank_line() {
        let (runner, _) = makeRunner(text: "a\n\nb", cursor: 2)
        let finished = expectation(description: "run finished")
        finished.isInverted = true
        runner.onRunFinished = { finished.fulfill() }

        runner.perform(.runBlockAtCursor)
        wait(for: [finished], timeout: 0.5)

        XCTAssertEqual(ranBlocks, [])
    }

    func test_should_reset_interpreter() {
        let (runner, _) = makeRunner(text: "a", cursor: 0)

        perform(.resetInterpreter, on: runner)

        XCTAssertEqual(resetCount, 1)
    }

    // A reset waits for the interpreter queue, so it would block until the run ends.
    func test_should_ignore_reset_while_running() {
        let (runner, _) = makeRunner(text: "a", cursor: 0)
        let finished = expectation(description: "run finished")
        runner.onRunFinished = { finished.fulfill() }
        runner.perform(.runBlockAtCursor)

        runner.perform(.resetInterpreter)
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(resetCount, 0)
    }

    func test_should_undo_inserted_result() {
        let (runner, textView) = makeRunner(text: "x", cursor: 0)
        textView.allowsUndo = true
        // The text view takes its undo manager from the window.
        let window = NSWindow()
        window.isReleasedWhenClosed = false
        window.contentView = textView
        addTeardownBlock { @MainActor in window.close() }

        perform(.runBlockAtCursor, on: runner)
        textView.undoManager?.undo()

        XCTAssertEqual(textView.string, "x")
    }

    func test_should_keep_text_read_only_while_running() {
        let (runner, textView) = makeRunner(text: "x", cursor: 0)
        let finished = expectation(description: "run finished")
        runner.onRunFinished = { finished.fulfill() }

        runner.perform(.runBlockAtCursor)
        let isEditableWhileRunning = textView.isEditable
        wait(for: [finished], timeout: 5)

        XCTAssertFalse(isEditableWhileRunning)
    }

    // Undo reaches the text view through the window even while it is read-only.
    func test_should_drop_results_when_text_changed_during_run() {
        let (runner, textView) = makeRunner(text: "x\n\ny", cursor: 0)
        let finished = expectation(description: "run finished")
        runner.onRunFinished = { finished.fulfill() }

        runner.perform(.runBlockAtCursor)
        textView.string = "z"
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(textView.string, "z")
    }

    func test_should_make_text_editable_after_run() {
        let (runner, textView) = makeRunner(text: "x", cursor: 0)

        perform(.runBlockAtCursor, on: runner)

        XCTAssertTrue(textView.isEditable)
    }

    func test_should_report_running_when_run_starts() {
        let (runner, _) = makeRunner(text: "x", cursor: 0)
        var statuses: [ScratchRunStatus] = []
        runner.onStatusChanged = { statuses.append($0) }

        perform(.runBlockAtCursor, on: runner)

        XCTAssertEqual(statuses, [.running, .idle])
    }

    func test_should_report_dropped_results_when_text_changed_during_run() {
        let (runner, textView) = makeRunner(text: "x", cursor: 0)
        var statuses: [ScratchRunStatus] = []
        runner.onStatusChanged = { statuses.append($0) }
        let finished = expectation(description: "run finished")
        runner.onRunFinished = { finished.fulfill() }

        runner.perform(.runBlockAtCursor)
        textView.string = "z"
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(statuses.last, .droppedResults)
    }
}
