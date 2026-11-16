import AppKit
import XCTest

@testable import Something

@MainActor
final class ScratchRunButtonsTests: XCTestCase {
    private var ranLines: [Int] = []

    private func makeRunButtons(text: String) -> (ScratchRunButtons, NSTextView) {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        let textView = scrollView.documentView as! NSTextView
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.string = text
        let runButtons = ScratchRunButtons(textView: textView) { [unowned self] lineIndex in
            ranLines.append(lineIndex)
        }
        runButtons.update()
        return (runButtons, textView)
    }

    func test_should_show_one_button_per_block() {
        let (runButtons, _) = makeRunButtons(text: "a\n\nb\n\nc")

        XCTAssertEqual(runButtons.buttons.count, 3)
    }

    func test_should_add_buttons_to_text_view() {
        let (runButtons, textView) = makeRunButtons(text: "a\n\nb")

        XCTAssertTrue(runButtons.buttons.allSatisfy { $0.superview === textView })
    }

    func test_should_show_no_button_for_comment_only_paragraph() {
        let (runButtons, _) = makeRunButtons(text: "# note\n\na")

        XCTAssertEqual(runButtons.buttons.count, 1)
    }

    func test_should_run_block_of_clicked_button() {
        let (runButtons, _) = makeRunButtons(text: "a\n\nb\nc")

        runButtons.buttons[1].performClick(nil)

        XCTAssertEqual(ranLines, [2])
    }

    func test_should_remove_button_of_deleted_block() {
        let (runButtons, textView) = makeRunButtons(text: "a\n\nb")
        textView.string = "a"

        runButtons.update()

        XCTAssertEqual(textView.subviews.filter { $0 is NSButton }.count, 1)
    }

    func test_should_put_lower_block_button_lower() {
        let (runButtons, _) = makeRunButtons(text: "a\n\n\n\nb")

        XCTAssertGreaterThan(runButtons.buttons[1].frame.minY, runButtons.buttons[0].frame.maxY)
    }

    func test_should_put_button_at_right_edge_of_text_view() {
        let (runButtons, textView) = makeRunButtons(text: "a")

        XCTAssertEqual(runButtons.buttons[0].frame.maxX, textView.bounds.maxX, accuracy: 8)
    }

    func test_should_center_button_on_first_line_of_block() {
        let (runButtons, textView) = makeRunButtons(text: "a\n\nb")
        let lineHeight = textView.font!.boundingRectForFont.height

        XCTAssertEqual(
            runButtons.buttons[1].frame.midY,
            textView.textContainerOrigin.y + lineHeight * 2.5,
            accuracy: lineHeight / 2
        )
    }

    // The scratch keys work only while the editor holds the keyboard focus.
    func test_should_leave_keyboard_focus_in_editor() {
        let (runButtons, _) = makeRunButtons(text: "a")

        XCTAssertFalse(runButtons.buttons[0].acceptsFirstResponder)
    }
}
