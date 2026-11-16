import AppKit

/// Shows a Run button at the right edge of the first line of each block in the scratch
/// buffer.
///
/// The buttons are subviews of the text view, so that they scroll with the text. They can
/// cover the end of a long line, which the text view does not wrap around them.
@MainActor
final class ScratchRunButtons {
    private static let toolTip = "Run this block (C-j)"
    private static let buttonSize = NSSize(width: 22, height: 18)
    private static let rightMargin: CGFloat = 4

    /// The buttons, one per block, top to bottom.
    private(set) var buttons: [NSButton] = []

    private let textView: NSTextView
    private let onRun: (Int) -> Void
    // The zero-based first line of the block of each button, in the order of `buttons`.
    private var blockStartLines: [Int] = []

    /// `onRun` receives the zero-based first line of the block whose button was clicked.
    init(textView: NSTextView, onRun: @escaping (Int) -> Void) {
        self.textView = textView
        self.onRun = onRun
    }

    /// Places the buttons again from the current text and layout. Call after the text or the
    /// width of the text view changes.
    ///
    /// Each call parses the whole buffer and lays it out up to the last block, which stays
    /// cheap for a scratch buffer of a few hundred lines.
    func update() {
        let lines = textView.string.components(separatedBy: "\n")
        let startLines = ScratchBlockParser.findBlocks(in: lines).map(\.lineRange.lowerBound)
        adjustButtonCount(to: startLines.count)
        blockStartLines = startLines
        let lineStartOffsets = findLineStartOffsets(of: lines)
        for (button, startLine) in zip(buttons, startLines) {
            guard let lineFrame = findLineFrame(atUTF16Offset: lineStartOffsets[startLine]) else {
                button.isHidden = true
                continue
            }
            button.isHidden = false
            button.frame = NSRect(
                x: textView.bounds.maxX - Self.buttonSize.width - Self.rightMargin,
                y: lineFrame.midY - Self.buttonSize.height / 2,
                width: Self.buttonSize.width,
                height: Self.buttonSize.height
            )
        }
    }

    private func adjustButtonCount(to count: Int) {
        while buttons.count > count {
            buttons.removeLast().removeFromSuperview()
        }
        while buttons.count < count {
            let button = makeButton()
            textView.addSubview(button)
            buttons.append(button)
        }
    }

    private func makeButton() -> NSButton {
        let image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Run")
        let button = NSButton(
            image: image ?? NSImage(),
            target: self,
            action: #selector(runBlockOfClickedButton(_:))
        )
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = Self.toolTip
        // The scratch keys act only while the editor is the first responder.
        button.refusesFirstResponder = true
        // Keeps the button on the right edge as the window resizes. Lines that wrap anew still
        // need `update()` to move the button down.
        button.autoresizingMask = [.minXMargin]
        return button
    }

    @objc
    private func runBlockOfClickedButton(_ sender: NSButton) {
        guard let buttonIndex = buttons.firstIndex(of: sender) else {
            return
        }
        onRun(blockStartLines[buttonIndex])
    }

    private func findLineStartOffsets(of lines: [String]) -> [Int] {
        lines.reduce(into: [0]) { offsets, line in
            offsets.append(offsets[offsets.count - 1] + line.utf16.count + 1)
        }
    }

    // Returns the frame of the line at `offset` in the coordinates of the text view.
    private func findLineFrame(atUTF16Offset offset: Int) -> NSRect? {
        let frameInContainer =
            if let layoutManager = textView.textLayoutManager {
                Self.findTextKit2LineFrame(atUTF16Offset: offset, in: layoutManager)
            } else {
                findTextKit1LineFrame(atUTF16Offset: offset)
            }
        let origin = textView.textContainerOrigin
        return frameInContainer?.offsetBy(dx: origin.x, dy: origin.y)
    }

    private static func findTextKit2LineFrame(
        atUTF16Offset offset: Int,
        in layoutManager: NSTextLayoutManager
    ) -> NSRect? {
        guard let contentManager = layoutManager.textContentManager,
            let location = contentManager.location(
                contentManager.documentRange.location,
                offsetBy: offset
            ),
            let layoutRange = NSTextRange(
                location: contentManager.documentRange.location,
                end: location
            )
        else {
            return nil
        }
        layoutManager.ensureLayout(for: layoutRange)
        guard let fragment = layoutManager.textLayoutFragment(for: location) else {
            return nil
        }
        let fragmentFrame = fragment.layoutFragmentFrame
        let lineBounds = fragment.textLineFragments.first?.typographicBounds ?? fragmentFrame
        return NSRect(
            x: fragmentFrame.minX,
            y: fragmentFrame.minY + lineBounds.minY,
            width: fragmentFrame.width,
            height: lineBounds.height
        )
    }

    // A text view drops TextKit 2 for good once any code reads its `layoutManager`, so this
    // path reads it only after `textLayoutManager` is already nil.
    private func findTextKit1LineFrame(atUTF16Offset offset: Int) -> NSRect? {
        guard let layoutManager = textView.layoutManager else {
            return nil
        }
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: offset)
        guard glyphIndex < layoutManager.numberOfGlyphs else {
            return nil
        }
        layoutManager.ensureLayout(forGlyphRange: NSRange(location: 0, length: glyphIndex + 1))
        return layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
    }
}
