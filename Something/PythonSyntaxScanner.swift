import Foundation

/// What a highlighted span of the scratch buffer holds.
enum PythonTokenKind: Equatable {
    case keyword
    case builtin
    case string
    case comment
    case number
    case decorator
    /// A `# => ` line that a run wrote.
    case result
    /// A `# !! ` line that a run wrote.
    case error
}

/// One highlighted span, as a UTF-16 range of the whole text so that it applies to
/// `NSTextStorage` as is.
struct PythonToken: Equatable {
    let kind: PythonTokenKind
    let range: NSRange
}

/// Finds the spans of Python source to color, line by line, carrying open triple-quoted
/// strings across lines.
///
/// `PythonLineScanner` tracks the same strings for the block parser but keeps only the state
/// at the end of each line, while the highlighter needs the span of each token. A change to
/// how either one reads strings, such as escapes, belongs in both, or the colors and the
/// blocks that C-j runs disagree.
enum PythonSyntaxScanner {
    /// Returns the tokens of `text` in order. Plain names, operators, and whitespace get no
    /// token.
    static func findTokens(in text: String) -> [PythonToken] {
        var tokens: [PythonToken] = []
        var openTripleQuote: Unicode.Scalar?
        var lineStartOffset = 0
        // The text view breaks a line at "\r" as well as at "\n". Splitting the scalars, not
        // the characters, also splits "\r\n", which Swift keeps as one Character.
        let lines = text.unicodeScalars.split(omittingEmptySubsequences: false) {
            $0 == "\n" || $0 == "\r"
        }
        for line in lines {
            var tokenizer = PythonLineTokenizer(
                scalars: Array(line),
                startOffset: lineStartOffset,
                openTripleQuote: openTripleQuote
            )
            tokenizer.tokenize()
            tokens += tokenizer.tokens
            openTripleQuote = tokenizer.openTripleQuote
            lineStartOffset += line.reduce(0) { $0 + $1.utf16.count } + 1
        }
        return tokens
    }
}

private let pythonKeywords: Set<String> = [
    "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class",
    "continue", "def", "del", "elif", "else", "except", "finally", "for", "from", "global",
    "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return",
    "try", "while", "with", "yield",
]

private let pythonBuiltins: Set<String> = [
    "abs", "all", "any", "bin", "bool", "bytes", "callable", "chr", "dict", "dir", "divmod",
    "enumerate", "filter", "float", "format", "getattr", "hasattr", "hash", "hex", "id",
    "input", "int", "isinstance", "issubclass", "iter", "len", "list", "map", "max", "min",
    "next", "object", "oct", "open", "ord", "pow", "print", "range", "repr", "reversed",
    "round", "set", "setattr", "slice", "sorted", "str", "sum", "super", "tuple", "type",
    "zip",
]

private let pythonStringPrefixes: Set<String> = [
    "r", "u", "b", "f", "br", "rb", "fr", "rf",
]

/// Tokenizes one line, given whether a triple-quoted string is open at its start.
private struct PythonLineTokenizer {
    let scalars: [Unicode.Scalar]
    /// The quote character of a triple-quoted string still open at the end of the line.
    private(set) var openTripleQuote: Unicode.Scalar?
    private(set) var tokens: [PythonToken] = []
    // The UTF-16 offset in the whole text of each scalar, plus one past the last.
    private let offsets: [Int]

    init(scalars: [Unicode.Scalar], startOffset: Int, openTripleQuote: Unicode.Scalar?) {
        self.scalars = scalars
        self.openTripleQuote = openTripleQuote
        offsets = scalars.reduce(into: [startOffset]) { offsets, scalar in
            offsets.append(offsets[offsets.count - 1] + scalar.utf16.count)
        }
    }

    mutating func tokenize() {
        var index = 0
        if let quote = openTripleQuote {
            let closingEnd = findTripleQuoteEnd(of: quote, from: 0)
            index = closingEnd ?? scalars.count
            openTripleQuote = closingEnd == nil ? quote : nil
            appendToken(.string, from: 0, to: index)
        } else if let resultKind = findResultKind() {
            appendToken(resultKind, from: 0, to: scalars.count)
            return
        }
        while index < scalars.count {
            index = scanToken(at: index)
        }
    }

    // Returns the index after the token that starts at `index`, or after the character there.
    private mutating func scanToken(at index: Int) -> Int {
        let scalar = scalars[index]
        if scalar == "#" {
            appendToken(.comment, from: index, to: scalars.count)
            return scalars.count
        }
        if scalar == "\"" || scalar == "'" {
            return scanString(from: index, quoteIndex: index)
        }
        if scalar == "@", isFirstOnLine(index) {
            return scanDecorator(from: index)
        }
        if startsNumber(at: index) {
            return scanNumber(from: index)
        }
        if scalar == "_" || scalar.properties.isXIDStart {
            return scanName(from: index)
        }
        return index + 1
    }

    private mutating func scanName(from startIndex: Int) -> Int {
        var endIndex = startIndex + 1
        while endIndex < scalars.count, scalars[endIndex].properties.isXIDContinue {
            endIndex += 1
        }
        let name = String(String.UnicodeScalarView(scalars[startIndex..<endIndex]))
        let isQuoteNext =
            endIndex < scalars.count && (scalars[endIndex] == "\"" || scalars[endIndex] == "'")
        if isQuoteNext, pythonStringPrefixes.contains(name.lowercased()) {
            return scanString(from: startIndex, quoteIndex: endIndex)
        }
        if pythonKeywords.contains(name) {
            appendToken(.keyword, from: startIndex, to: endIndex)
        } else if pythonBuiltins.contains(name), !isAfterDot(startIndex) {
            appendToken(.builtin, from: startIndex, to: endIndex)
        }
        return endIndex
    }

    private mutating func scanString(from startIndex: Int, quoteIndex: Int) -> Int {
        let quote = scalars[quoteIndex]
        if isTripleQuote(at: quoteIndex, quote) {
            guard let endIndex = findTripleQuoteEnd(of: quote, from: quoteIndex + 3) else {
                openTripleQuote = quote
                appendToken(.string, from: startIndex, to: scalars.count)
                return scalars.count
            }
            appendToken(.string, from: startIndex, to: endIndex)
            return endIndex
        }
        var scanIndex = quoteIndex + 1
        while scanIndex < scalars.count, scalars[scanIndex] != quote {
            scanIndex += scalars[scanIndex] == "\\" ? 2 : 1
        }
        let endIndex = min(scanIndex + 1, scalars.count)
        appendToken(.string, from: startIndex, to: endIndex)
        return endIndex
    }

    private mutating func scanDecorator(from startIndex: Int) -> Int {
        var endIndex = startIndex + 1
        while endIndex < scalars.count, isDottedNamePart(scalars[endIndex]) {
            endIndex += 1
        }
        if endIndex > startIndex + 1 {
            appendToken(.decorator, from: startIndex, to: endIndex)
        }
        return endIndex
    }

    // Takes in hex digits, a fraction, and the sign of an exponent such as `1e-5`.
    private mutating func scanNumber(from startIndex: Int) -> Int {
        let isHex =
            startIndex + 1 < scalars.count && scalars[startIndex] == "0"
            && (scalars[startIndex + 1] == "x" || scalars[startIndex + 1] == "X")
        var endIndex = startIndex
        while endIndex < scalars.count {
            let scalar = scalars[endIndex]
            let isExponentSign =
                (scalar == "+" || scalar == "-") && !isHex
                && endIndex > startIndex
                && (scalars[endIndex - 1] == "e" || scalars[endIndex - 1] == "E")
            guard scalar == "." || scalar.properties.isXIDContinue || isExponentSign else {
                break
            }
            endIndex += 1
        }
        appendToken(.number, from: startIndex, to: endIndex)
        return endIndex
    }

    // Returns the index after the closing quotes, or nil when the string stays open.
    private func findTripleQuoteEnd(of quote: Unicode.Scalar, from startIndex: Int) -> Int? {
        var scanIndex = startIndex
        while scanIndex < scalars.count {
            if scalars[scanIndex] == "\\" {
                scanIndex += 2
            } else if isTripleQuote(at: scanIndex, quote) {
                return scanIndex + 3
            } else {
                scanIndex += 1
            }
        }
        return nil
    }

    private func findResultKind() -> PythonTokenKind? {
        let line = String(String.UnicodeScalarView(scalars))
        if line.hasPrefix(ScratchBlockParser.outputPrefix) {
            return .result
        }
        return line.hasPrefix(ScratchBlockParser.errorPrefix) ? .error : nil
    }

    private func isTripleQuote(at index: Int, _ quote: Unicode.Scalar) -> Bool {
        index + 3 <= scalars.count && scalars[index..<(index + 3)].allSatisfy { $0 == quote }
    }

    private func isFirstOnLine(_ index: Int) -> Bool {
        scalars[..<index].allSatisfy { $0.properties.isWhitespace }
    }

    private func isAfterDot(_ index: Int) -> Bool {
        scalars[..<index].last { !$0.properties.isWhitespace } == "."
    }

    // A leading dot starts a number such as `.5`, but not an attribute such as `x.y`, whose
    // dot the name scan never reaches.
    private func startsNumber(at index: Int) -> Bool {
        let scalar = scalars[index]
        let isDotBeforeDigit =
            scalar == "." && index + 1 < scalars.count
            && isDigit(scalars[index + 1])
        return isDigit(scalar) || isDotBeforeDigit
    }

    private func isDottedNamePart(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "." || scalar.properties.isXIDContinue
    }

    private func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar)
    }

    private mutating func appendToken(
        _ kind: PythonTokenKind,
        from startIndex: Int,
        to endIndex: Int
    ) {
        guard endIndex > startIndex else {
            return
        }
        let location = offsets[startIndex]
        tokens.append(
            PythonToken(
                kind: kind,
                range: NSRange(location: location, length: offsets[endIndex] - location)
            )
        )
    }
}
