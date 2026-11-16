import AppKit

/// Colors the Python source in the scratch text view.
///
/// The colors live in the text storage only:
/// - The saved file holds the plain `string` of the text view, without attributes.
/// - The undo history skips them, since the storage changes outside `shouldChangeText`.
///
/// System colors follow the dark mode setting.
@MainActor
final class ScratchHighlighter {
    private let textView: NSTextView

    init(textView: NSTextView) {
        self.textView = textView
    }

    /// Returns the text color of `kind`.
    static func color(for kind: PythonTokenKind) -> NSColor {
        switch kind {
        case .keyword: .systemPink
        case .builtin: .systemPurple
        case .string: .systemOrange
        case .comment: .systemGray
        case .number: .systemBlue
        case .decorator: .systemTeal
        case .result: .systemGreen
        case .error: .systemRed
        }
    }

    /// Colors the whole text again. Call after the text changes.
    ///
    /// Only the ranges whose color changes are written, since a write marks its range edited
    /// and TextKit 2 then lays that range out again.
    func update() {
        guard let textStorage = textView.textStorage else {
            return
        }
        let tokens = PythonSyntaxScanner.findTokens(in: textStorage.string)
        var targetColorRanges: [(range: NSRange, color: NSColor)] = []
        var plainStart = 0
        for token in tokens {
            targetColorRanges.append(
                (Self.makeRange(from: plainStart, to: token.range.location), .textColor)
            )
            targetColorRanges.append((token.range, Self.color(for: token.kind)))
            plainStart = NSMaxRange(token.range)
        }
        targetColorRanges.append(
            (Self.makeRange(from: plainStart, to: textStorage.length), .textColor)
        )
        let staleColorRanges = targetColorRanges.flatMap { range, color in
            Self.findChangedRanges(in: range, to: color, of: textStorage).map { ($0, color) }
        }
        guard !staleColorRanges.isEmpty else {
            return
        }
        textStorage.beginEditing()
        for (range, color) in staleColorRanges {
            textStorage.addAttribute(.foregroundColor, value: color, range: range)
        }
        textStorage.endEditing()
    }

    private static func makeRange(from start: Int, to end: Int) -> NSRange {
        NSRange(location: start, length: max(end - start, 0))
    }

    // Returns the parts of `range` whose color differs from `color`.
    private static func findChangedRanges(
        in range: NSRange,
        to color: NSColor,
        of textStorage: NSTextStorage
    ) -> [NSRange] {
        guard range.length > 0 else {
            return []
        }
        var changedRanges: [NSRange] = []
        textStorage.enumerateAttribute(.foregroundColor, in: range) { value, subrange, _ in
            if value as? NSColor != color {
                changedRanges.append(subrange)
            }
        }
        return changedRanges
    }
}
