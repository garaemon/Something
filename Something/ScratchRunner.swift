import AppKit

/// Runs the blocks of the scratch buffer and writes their results under them.
///
/// Python runs off the main thread, since a run can take until the watchdog stops it. The
/// text view stays read-only meanwhile, so that the line numbers of the blocks still hold
/// when the results come back.
@MainActor
final class ScratchRunner {
    /// Called on the main thread after the results of a run are in the text, or after a
    /// reset ends.
    var onRunFinished: (() -> Void)?

    private let textView: NSTextView
    private let runPython: @Sendable (PythonBlock) -> PythonRunResult
    private let resetPython: @Sendable () -> Void
    private var isRunning = false

    init(
        textView: NSTextView,
        runPython: @escaping @Sendable (PythonBlock) -> PythonRunResult = {
            PythonInterpreter.shared.run($0)
        },
        resetPython: @escaping @Sendable () -> Void = { PythonInterpreter.shared.reset() }
    ) {
        self.textView = textView
        self.runPython = runPython
        self.resetPython = resetPython
    }

    /// Starts `command`. A command that starts while another is in progress does nothing.
    func perform(_ command: ScratchCommand) {
        let lines = textView.string.components(separatedBy: "\n")
        switch command {
        case .runBlockAtCursor:
            let cursorLine = Self.findLineIndex(
                ofUTF16Offset: textView.selectedRange().location,
                in: textView.string
            )
            let block = ScratchBlockParser.findBlock(in: lines, containingLine: cursorLine)
            run(block.map { [$0] } ?? [], in: lines)
        case .runAllBlocks:
            run(ScratchBlockParser.findBlocks(in: lines), in: lines)
        case .resetInterpreter:
            reset()
        }
    }

    // The reset waits on the interpreter queue, so it runs off the main thread too.
    private func reset() {
        guard !isRunning else {
            return
        }
        isRunning = true
        let resetPython = resetPython
        DispatchQueue.global(qos: .userInitiated).async {
            resetPython()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isRunning = false
                    self.onRunFinished?()
                }
            }
        }
    }

    private func run(_ blocks: [ScratchBlock], in lines: [String]) {
        guard !isRunning, !blocks.isEmpty else {
            return
        }
        isRunning = true
        textView.isEditable = false
        let sources = blocks.map { block in
            ScratchBlockParser.makePythonBlock(from: Array(lines[block.lineRange]))
        }
        let runPython = runPython
        DispatchQueue.global(qos: .userInitiated).async {
            let results = sources.map(runPython)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.finishRun(blocks: blocks, results: results, lines: lines)
                }
            }
        }
    }

    private func finishRun(blocks: [ScratchBlock], results: [PythonRunResult], lines: [String]) {
        textView.isEditable = true
        textView.undoManager?.beginUndoGrouping()
        // Bottom-up, so that each replacement leaves the offsets of the blocks above intact.
        for (block, result) in zip(blocks, results).reversed() {
            replaceOutput(of: block, with: ScratchBlockParser.formatResult(result), in: lines)
        }
        textView.undoManager?.endUndoGrouping()
        isRunning = false
        onRunFinished?()
    }

    // Replaces the text from the end of the last code line to the end of the last result
    // line, so that a block on the last line without a newline gains one.
    private func replaceOutput(
        of block: ScratchBlock,
        with resultLines: [String],
        in lines: [String]
    ) {
        let codeEndOffset = Self.findEndOffset(ofLine: block.lineRange.upperBound - 1, in: lines)
        let outputEndOffset = Self.findEndOffset(
            ofLine: block.outputRange.upperBound - 1,
            in: lines
        )
        let outputRange = NSRange(
            location: codeEndOffset,
            length: outputEndOffset - codeEndOffset
        )
        let outputText = resultLines.map { "\n" + $0 }.joined()
        guard textView.shouldChangeText(in: outputRange, replacementString: outputText) else {
            return
        }
        textView.textStorage?.replaceCharacters(in: outputRange, with: outputText)
        textView.didChangeText()
    }

    private static func findEndOffset(ofLine lineIndex: Int, in lines: [String]) -> Int {
        lines[...lineIndex].reduce(0) { $0 + $1.utf16.count } + lineIndex
    }

    private static func findLineIndex(ofUTF16Offset offset: Int, in text: String) -> Int {
        let utf16 = text.utf16
        let end = utf16.index(utf16.startIndex, offsetBy: min(offset, utf16.count))
        return utf16[..<end].reduce(0) { $1 == 0x0A ? $0 + 1 : $0 }
    }
}
