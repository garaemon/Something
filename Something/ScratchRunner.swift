import AppKit

/// What the runner is doing, for the window to show.
enum ScratchRunStatus: Equatable {
    case idle
    case running
    /// The last run ended after the text changed, such as by undo, so its results were not
    /// written.
    case droppedResults
}

/// Runs the blocks of the scratch buffer and writes their results under them.
///
/// Python runs off the main thread, since a run can take until the watchdog stops it. The
/// text view stays read-only meanwhile, so that the line numbers of the blocks still hold
/// when the results come back.
@MainActor
final class ScratchRunner {
    /// Called on the main thread after a run or a reset ends. A run whose text changed
    /// meanwhile, such as by undo, drops its results.
    var onRunFinished: (() -> Void)?
    /// Called on the main thread when a run or a reset starts or ends.
    var onStatusChanged: ((ScratchRunStatus) -> Void)?

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
        switch command {
        case .runBlockAtCursor:
            let cursorLine = Self.findLineIndex(
                ofUTF16Offset: textView.selectedRange().location,
                in: textView.string
            )
            runBlock(atLine: cursorLine)
        case .runAllBlocks:
            let lines = textView.string.components(separatedBy: "\n")
            run(ScratchBlockParser.findBlocks(in: lines), in: lines)
        case .resetInterpreter:
            reset()
        }
    }

    /// Runs the block whose code or result lines hold the zero-based `lineIndex`, such as
    /// from a Run button. Does nothing when no block holds the line or a command is running.
    func runBlock(atLine lineIndex: Int) {
        let lines = textView.string.components(separatedBy: "\n")
        let block = ScratchBlockParser.findBlock(in: lines, containingLine: lineIndex)
        run(block.map { [$0] } ?? [], in: lines)
    }

    // The reset waits on the interpreter queue, so it runs off the main thread too.
    private func reset() {
        guard !isRunning else {
            return
        }
        isRunning = true
        onStatusChanged?(.running)
        let resetPython = resetPython
        DispatchQueue.global(qos: .userInitiated).async {
            resetPython()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.endCommand(with: .idle)
                }
            }
        }
    }

    private func run(_ blocks: [ScratchBlock], in lines: [String]) {
        guard !isRunning, !blocks.isEmpty else {
            return
        }
        isRunning = true
        onStatusChanged?(.running)
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
        // Undo still edits a read-only text view, and the results would land at stale offsets.
        guard textView.string == lines.joined(separator: "\n") else {
            endCommand(with: .droppedResults)
            return
        }
        textView.undoManager?.beginUndoGrouping()
        // Bottom-up, so that each replacement leaves the offsets of the blocks above intact.
        for (block, result) in zip(blocks, results).reversed() {
            replaceOutput(of: block, with: ScratchBlockParser.formatResult(result), in: lines)
        }
        textView.undoManager?.endUndoGrouping()
        endCommand(with: .idle)
    }

    private func endCommand(with status: ScratchRunStatus) {
        isRunning = false
        onStatusChanged?(status)
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
