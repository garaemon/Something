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
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScratchWindowControllerTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folderURL) }
        let store = ScratchStore(fileURL: folderURL.appendingPathComponent("scratch.py"))
        try store.saveText("")
        try Data([0xFF, 0xFE]).write(to: store.fileURL)
        let controller = ScratchWindowController(store: store)
        addTeardownBlock { @MainActor in controller.window.close() }

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
}
