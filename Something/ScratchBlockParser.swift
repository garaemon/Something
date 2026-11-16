import Foundation

/// One block of the scratch buffer, as half-open ranges of zero-based line indices.
struct ScratchBlock: Equatable {
    /// The lines of the paragraph, up to the line before its first result line or the
    /// blank line that ends it. Trailing comment lines belong to it.
    let lineRange: Range<Int>
    /// The result lines right under the code, empty when the block has none.
    let outputRange: Range<Int>
}

/// Finds the blocks of the scratch buffer, splits one into a `PythonBlock`, and turns a run
/// into result lines.
///
/// A block is a paragraph that holds code. A blank line ends the paragraph unless the next
/// non-blank line is indented, which keeps a function body with blank lines in one block.
/// Lines inside a triple-quoted string belong to the block of the string, whatever they hold.
enum ScratchBlockParser {
    static let outputPrefix = "# => "
    static let errorPrefix = "# !! "

    // `case` is left out: it is indented under `match`, so it never starts in column zero.
    private static let continuationKeywords = ["elif", "else", "except", "finally"]

    /// Returns every block of `lines`, top to bottom.
    static func findBlocks(in lines: [String]) -> [ScratchBlock] {
        let startsInsideString = findLinesStartingInsideString(lines)
        var blocks: [ScratchBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let isInsideBlock = isIndented(line) || startsInsideString[index]
            if isBlank(line) || isOutputLine(line) || isInsideBlock {
                index += 1
                continue
            }
            let endIndex = findBlockEnd(
                in: lines,
                from: index,
                startsInsideString: startsInsideString
            )
            if lines[index...endIndex].contains(where: isCodeLine) {
                let outputEnd = findOutputEnd(in: lines, after: endIndex)
                blocks.append(
                    ScratchBlock(
                        lineRange: index..<(endIndex + 1),
                        outputRange: (endIndex + 1)..<outputEnd
                    )
                )
            }
            index = endIndex + 1
        }
        return blocks
    }

    /// Returns the block whose code or result lines hold `lineIndex`, or nil.
    static func findBlock(in lines: [String], containingLine lineIndex: Int) -> ScratchBlock? {
        findBlocks(in: lines).first { block in
            block.lineRange.lowerBound <= lineIndex && lineIndex < block.outputRange.upperBound
        }
    }

    /// Splits the code lines of a block before its last top-level statement, so that the
    /// value of that statement can be echoed.
    static func makePythonBlock(from blockLines: [String]) -> PythonBlock {
        var lineState = PythonLineState()
        var lastStatementStart = 0
        for (index, line) in blockLines.enumerated() {
            let followsDecorator = index > 0 && blockLines[index - 1].hasPrefix("@")
            if lineState == PythonLineState(), !followsDecorator, startsStatement(line) {
                lastStatementStart = index
            }
            lineState = PythonLineScanner.scan(line, from: lineState)
        }
        return PythonBlock(
            leadingSource: blockLines[..<lastStatementStart].joined(separator: "\n"),
            lastStatement: blockLines[lastStatementStart...].joined(separator: "\n")
        )
    }

    /// Returns the printed output as `# => ` lines, followed by the error as `# !! ` lines.
    static func formatResult(_ result: PythonRunResult) -> [String] {
        let outputLines = splitIntoLines(result.output).map { outputPrefix + $0 }
        let errorLines = splitIntoLines(result.errorMessage ?? "").map { errorPrefix + $0 }
        return outputLines + errorLines
    }

    static func isOutputLine(_ line: String) -> Bool {
        line.hasPrefix(outputPrefix) || line.hasPrefix(errorPrefix)
    }

    private static func findBlockEnd(
        in lines: [String],
        from startIndex: Int,
        startsInsideString: [Bool]
    ) -> Int {
        var endIndex = startIndex
        var index = startIndex + 1
        while index < lines.count {
            if startsInsideString[index] {
                endIndex = index
            } else if isOutputLine(lines[index]) {
                break
            } else if isBlank(lines[index]) {
                let nextLine = lines[(index + 1)...].first { !isBlank($0) }
                guard let nextLine, isIndented(nextLine) else {
                    break
                }
            } else {
                endIndex = index
            }
            index += 1
        }
        return endIndex
    }

    private static func findOutputEnd(in lines: [String], after endIndex: Int) -> Int {
        var outputEnd = endIndex + 1
        while outputEnd < lines.count, isOutputLine(lines[outputEnd]) {
            outputEnd += 1
        }
        return outputEnd
    }

    private static func splitIntoLines(_ text: String) -> [String] {
        guard !text.isEmpty else {
            return []
        }
        // A carriage return, such as from a progress display, also starts a line in the
        // text view, so it needs a prefix of its own.
        let trimmedText = text.last?.isNewline == true ? String(text.dropLast()) : text
        return trimmedText.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map(String.init)
    }

    // The bracket depth is not carried over, so that a stray bracket in one block does not
    // spill into the blocks below.
    private static func findLinesStartingInsideString(_ lines: [String]) -> [Bool] {
        var openTripleQuote: String?
        return lines.map { line in
            let startsInsideString = openTripleQuote != nil
            let startState = PythonLineState(openTripleQuote: openTripleQuote)
            openTripleQuote = PythonLineScanner.scan(line, from: startState).openTripleQuote
            return startsInsideString
        }
    }

    private static func isBlank(_ line: String) -> Bool {
        line.allSatisfy(\.isWhitespace)
    }

    private static func isIndented(_ line: String) -> Bool {
        line.first?.isWhitespace == true && !isBlank(line)
    }

    private static func isCodeLine(_ line: String) -> Bool {
        !isBlank(line) && !line.drop(while: \.isWhitespace).hasPrefix("#")
    }

    // An `else:` or `except:` line continues the statement above instead of starting one.
    private static func startsStatement(_ line: String) -> Bool {
        let firstWord = String(line.prefix { $0.isLetter || $0.isNumber || $0 == "_" })
        return isCodeLine(line) && !isIndented(line) && !continuationKeywords.contains(firstWord)
    }
}
