import Foundation

/// One block of the scratch buffer, as half-open ranges of zero-based line indices.
struct ScratchBlock: Equatable {
    /// The lines of code, from the first line of the paragraph to its last code line.
    let lineRange: Range<Int>
    /// The result lines right under the code, empty when the block has none.
    let outputRange: Range<Int>
}

/// Finds the blocks of the scratch buffer, splits one into a `PythonBlock`, and turns a run
/// into result lines.
///
/// A block is a paragraph that holds code. A blank line ends the paragraph unless the next
/// non-blank line is indented, which keeps a function body with blank lines in one block.
enum ScratchBlockParser {
    static let outputPrefix = "# => "
    static let errorPrefix = "# !! "

    private static let continuationKeywords = ["elif", "else", "except", "finally", "case"]

    /// Returns every block of `lines`, top to bottom.
    static func findBlocks(in lines: [String]) -> [ScratchBlock] {
        var blocks: [ScratchBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if isBlank(line) || isOutputLine(line) || isIndented(line) {
                index += 1
                continue
            }
            let endIndex = findBlockEnd(in: lines, from: index)
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
        var bracketDepth = 0
        var lastStart = 0
        for (index, line) in blockLines.enumerated() {
            let followsDecorator = index > 0 && blockLines[index - 1].hasPrefix("@")
            if bracketDepth == 0, !followsDecorator, startsStatement(line) {
                lastStart = index
            }
            if isCodeLine(line) {
                bracketDepth += countBracketDepthChange(line)
            }
        }
        return PythonBlock(
            leadingSource: blockLines[..<lastStart].joined(separator: "\n"),
            lastStatement: blockLines[lastStart...].joined(separator: "\n")
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

    private static func findBlockEnd(in lines: [String], from startIndex: Int) -> Int {
        var endIndex = startIndex
        var index = startIndex + 1
        while index < lines.count, !isOutputLine(lines[index]) {
            if isBlank(lines[index]) {
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
        let trimmedText = text.hasSuffix("\n") ? String(text.dropLast()) : text
        return trimmedText.components(separatedBy: "\n")
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
        let firstWord = String(line.prefix { $0.isLetter })
        return isCodeLine(line) && !isIndented(line) && !continuationKeywords.contains(firstWord)
    }

    // Skips brackets inside string literals and after a comment marker. A string that
    // spans lines, such as a triple-quoted one, is not tracked.
    private static func countBracketDepthChange(_ line: String) -> Int {
        var depthChange = 0
        var openQuote: Character?
        var isEscaped = false
        for character in line {
            if let quote = openQuote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == quote {
                    openQuote = nil
                }
                continue
            }
            switch character {
            case "\"", "'": openQuote = character
            case "#": return depthChange
            case "(", "[", "{": depthChange += 1
            case ")", "]", "}": depthChange -= 1
            default: break
            }
        }
        return depthChange
    }
}
