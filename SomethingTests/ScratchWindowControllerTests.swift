import AppKit
import XCTest

@testable import Something

@MainActor
final class ScratchWindowControllerTests: XCTestCase {
    private func makeController(runResult: PythonRunResult) -> ScratchWindowController {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScratchWindowControllerTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folderURL) }
        let controller = ScratchWindowController(
            store: ScratchStore(fileURL: folderURL.appendingPathComponent("scratch.py")),
            makeRunner: { textView in
                ScratchRunner(textView: textView, runPython: { _ in runResult }, resetPython: {})
            }
        )
        addTeardownBlock { @MainActor in controller.window.close() }
        return controller
    }

    // Bytes that are not UTF-8 make the scratch file unreadable.
    private func makeControllerOfUnreadableFile() throws -> ScratchWindowController {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScratchWindowControllerTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folderURL) }
        let store = ScratchStore(fileURL: folderURL.appendingPathComponent("scratch.py"))
        try store.saveText("")
        try Data([0xFF, 0xFE]).write(to: store.fileURL)
        let controller = ScratchWindowController(store: store)
        addTeardownBlock { @MainActor in controller.window.close() }
        return controller
    }

    private func makeKeyEvent(_ key: String, modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: 0
        )!
    }

    func test_should_consume_control_j() {
        let controller = makeController(runResult: PythonRunResult(output: "", errorMessage: nil))

        let passedEvent = controller.handleKeyDown(makeKeyEvent("j", modifiers: .control))

        XCTAssertNil(passedEvent)
    }

    func test_should_pass_plain_key_to_text_view() {
        let controller = makeController(runResult: PythonRunResult(output: "", errorMessage: nil))

        let passedEvent = controller.handleKeyDown(makeKeyEvent("j", modifiers: []))

        XCTAssertNotNil(passedEvent)
    }

    func test_should_insert_result_on_control_j() {
        let controller = makeController(runResult: PythonRunResult(output: "3\n", errorMessage: nil))
        controller.textView.string = "1 + 2"
        controller.textView.setSelectedRange(NSRange(location: 0, length: 0))
        let finished = expectation(description: "run finished")
        controller.onRunFinished = { finished.fulfill() }

        _ = controller.handleKeyDown(makeKeyEvent("j", modifiers: .control))
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(controller.textView.string, "1 + 2\n# => 3")
    }

    func test_should_pass_control_j_through_when_file_cannot_be_read() throws {
        let controller = try makeControllerOfUnreadableFile()

        let passedEvent = controller.handleKeyDown(makeKeyEvent("j", modifiers: .control))

        XCTAssertNotNil(passedEvent)
    }

    // An input method composing text, such as Japanese kana, uses C-j and C-c itself.
    func test_should_pass_control_j_through_while_composing_text() {
        let controller = makeController(runResult: PythonRunResult(output: "", errorMessage: nil))
        controller.textView.setMarkedText(
            "\u{304B}",
            selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )

        let passedEvent = controller.handleKeyDown(makeKeyEvent("j", modifiers: .control))

        XCTAssertNotNil(passedEvent)
    }

    func test_should_show_running_in_subtitle_during_run() {
        let controller = makeController(runResult: PythonRunResult(output: "", errorMessage: nil))
        controller.textView.string = "1 + 2"
        let finished = expectation(description: "run finished")
        controller.onRunFinished = { finished.fulfill() }

        _ = controller.handleKeyDown(makeKeyEvent("j", modifiers: .control))
        let subtitleWhileRunning = controller.window.subtitle
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(subtitleWhileRunning, ScratchSubtitle.runningText)
    }

    // Typing schedules an autosave, which can land while the block still runs.
    func test_should_keep_running_subtitle_after_autosave_succeeds() {
        let controller = makeController(runResult: PythonRunResult(output: "", errorMessage: nil))
        controller.textView.string = "1 + 2"
        controller.textView.insertText(" ", replacementRange: NSRange(location: 5, length: 0))
        let finished = expectation(description: "run finished")
        controller.onRunFinished = { finished.fulfill() }

        _ = controller.handleKeyDown(makeKeyEvent("j", modifiers: .control))
        controller.saveNow()
        let subtitleAfterSave = controller.window.subtitle
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(subtitleAfterSave, ScratchSubtitle.runningText)
    }

    func test_should_show_run_button_for_block_of_initial_text() {
        let controller = makeController(runResult: PythonRunResult(output: "", errorMessage: nil))

        XCTAssertEqual(controller.runButtons?.buttons.count, 1)
    }

    func test_should_insert_result_on_run_button_click() {
        let controller = makeController(runResult: PythonRunResult(output: "3\n", errorMessage: nil))
        let finished = expectation(description: "run finished")
        controller.onRunFinished = { finished.fulfill() }

        controller.runButtons?.buttons.first?.performClick(nil)
        wait(for: [finished], timeout: 5)

        XCTAssertTrue(controller.textView.string.contains("1 + 2\n# => 3\n"))
    }

    func test_should_add_run_button_for_typed_block() {
        let controller = makeController(runResult: PythonRunResult(output: "", errorMessage: nil))
        let endOffset = controller.textView.string.utf16.count

        controller.textView.insertText(
            "\nx = 1",
            replacementRange: NSRange(location: endOffset, length: 0)
        )

        XCTAssertEqual(controller.runButtons?.buttons.count, 2)
    }

    func test_should_show_no_run_button_when_file_cannot_be_read() throws {
        let controller = try makeControllerOfUnreadableFile()

        XCTAssertNil(controller.runButtons)
    }

    func test_should_move_run_button_down_when_narrower_window_wraps_line_above() throws {
        let controller = makeController(runResult: PythonRunResult(output: "", errorMessage: nil))
        let longLine = "x = '" + String(repeating: "a", count: 60) + "'"
        controller.textView.insertText(
            longLine + "\n\nb",
            replacementRange: NSRange(location: 0, length: controller.textView.string.utf16.count)
        )
        let lowerButton = try XCTUnwrap(controller.runButtons?.buttons.last)
        let wideMinY = lowerButton.frame.minY

        controller.window.setContentSize(NSSize(width: 250, height: 480))

        XCTAssertGreaterThan(lowerButton.frame.minY, wideMinY)
    }
}
