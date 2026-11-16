import AppKit
import XCTest

@testable import Something

@MainActor
final class ScratchHighlighterTests: XCTestCase {
    private func makeHighlightedTextView(text: String) -> (ScratchHighlighter, NSTextView) {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.string = text
        let highlighter = ScratchHighlighter(textView: textView)
        highlighter.update()
        return (highlighter, textView)
    }

    private func findColor(at location: Int, in textView: NSTextView) -> NSColor? {
        textView.textStorage?.attribute(.foregroundColor, at: location, effectiveRange: nil)
            as? NSColor
    }

    func test_should_color_keyword() {
        let (_, textView) = makeHighlightedTextView(text: "def f(): pass")

        XCTAssertEqual(findColor(at: 0, in: textView), ScratchHighlighter.color(for: .keyword))
    }

    func test_should_color_plain_name_as_text() {
        let (_, textView) = makeHighlightedTextView(text: "def f(): pass")

        XCTAssertEqual(findColor(at: 4, in: textView), .textColor)
    }

    func test_should_clear_color_of_text_that_is_no_longer_keyword() {
        let (highlighter, textView) = makeHighlightedTextView(text: "def")
        textView.textStorage?.replaceCharacters(in: NSRange(location: 2, length: 1), with: "x")

        highlighter.update()

        XCTAssertEqual(findColor(at: 0, in: textView), .textColor)
    }

    func test_should_keep_font() {
        let (_, textView) = makeHighlightedTextView(text: "'s' # c")

        let font = textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont

        XCTAssertEqual(font, .monospacedSystemFont(ofSize: 13, weight: .regular))
    }

    func test_should_color_every_kind_apart_from_text() {
        let kinds = PythonTokenKind.allCases

        let colors = Set(kinds.map(ScratchHighlighter.color(for:)))

        XCTAssertEqual(colors.subtracting([NSColor.textColor]).count, kinds.count)
    }

    func test_should_tell_error_line_apart_from_result_line() {
        let (_, textView) = makeHighlightedTextView(text: "# => 1\n# !! E")

        XCTAssertNotEqual(findColor(at: 0, in: textView), findColor(at: 7, in: textView))
    }

    // An attribute write marks its range edited, and TextKit 2 then lays the range out again.
    func test_should_not_edit_text_storage_when_colors_are_unchanged() {
        let (highlighter, textView) = makeHighlightedTextView(text: "def f(): return 'x'  # c")
        var editCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: NSTextStorage.didProcessEditingNotification,
            object: textView.textStorage,
            queue: nil
        ) { _ in editCount += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        highlighter.update()

        XCTAssertEqual(editCount, 0)
    }
}
