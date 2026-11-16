import Foundation

/// The part of the Python tokenizer state that carries over from one line to the next.
struct PythonLineState: Equatable {
    /// The quote, `"""` or `'''`, of a triple-quoted string that is still open, or nil.
    var openTripleQuote: String?
    /// How many brackets are open. Negative after a stray closing bracket.
    var bracketDepth = 0
}

/// Tracks strings, comments, and brackets line by line, which is enough to tell where a
/// top-level statement starts without a full Python tokenizer.
///
/// A backslash at the end of a line, which also continues a statement, is not tracked.
/// `PythonSyntaxScanner` reads strings the same way for the highlighter, and a change to one
/// belongs in the other.
enum PythonLineScanner {
    /// Returns the state at the end of `line`, given the state at its start.
    static func scan(_ line: String, from startState: PythonLineState) -> PythonLineState {
        let characters = Array(line)
        var openTripleQuote = startState.openTripleQuote
        var bracketDepth = startState.bracketDepth
        var index = 0
        while index < characters.count {
            if let tripleQuote = openTripleQuote {
                if characters[index] == "\\" {
                    index += 2
                } else if matches(tripleQuote, at: index, in: characters) {
                    openTripleQuote = nil
                    index += 3
                } else {
                    index += 1
                }
                continue
            }
            let character = characters[index]
            switch character {
            case "#":
                return PythonLineState(openTripleQuote: nil, bracketDepth: bracketDepth)
            case "\"", "'":
                let tripleQuote = String(repeating: character, count: 3)
                if matches(tripleQuote, at: index, in: characters) {
                    openTripleQuote = tripleQuote
                    index += 3
                } else {
                    index = findShortStringEnd(characters, from: index)
                }
                continue
            case "(", "[", "{": bracketDepth += 1
            case ")", "]", "}": bracketDepth -= 1
            default: break
            }
            index += 1
        }
        return PythonLineState(openTripleQuote: openTripleQuote, bracketDepth: bracketDepth)
    }

    private static func matches(_ quote: String, at index: Int, in line: [Character]) -> Bool {
        line[index...].starts(with: Array(quote))
    }

    // Returns the index after the closing quote, or the end of the line for an unclosed one.
    private static func findShortStringEnd(_ line: [Character], from openIndex: Int) -> Int {
        let quote = line[openIndex]
        var scanIndex = openIndex + 1
        while scanIndex < line.count, line[scanIndex] != quote {
            scanIndex += line[scanIndex] == "\\" ? 2 : 1
        }
        return min(scanIndex + 1, line.count)
    }
}
