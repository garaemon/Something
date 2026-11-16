import AppKit

/// Colors the Python source in the scratch text view.
///
/// The colors live in the text storage only. Neither the saved file nor the undo history
/// records them, since the storage changes outside `shouldChangeText`. System colors follow
/// the dark mode setting.
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
    func update() {
        guard let textStorage = textView.textStorage else {
            return
        }
        let tokens = PythonSyntaxScanner.findTokens(in: textStorage.string)
        textStorage.beginEditing()
        textStorage.addAttribute(
            .foregroundColor,
            value: NSColor.textColor,
            range: NSRange(location: 0, length: textStorage.length)
        )
        for token in tokens {
            textStorage.addAttribute(
                .foregroundColor,
                value: Self.color(for: token.kind),
                range: token.range
            )
        }
        textStorage.endEditing()
    }
}
