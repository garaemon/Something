import XCTest

@testable import Something

final class PythonLineScannerTests: XCTestCase {
    func test_should_count_open_brackets() {
        let state = PythonLineScanner.scan("f([1,", from: PythonLineState())

        XCTAssertEqual(state.bracketDepth, 2)
    }

    func test_should_ignore_brackets_in_short_strings_and_comments() {
        let state = PythonLineScanner.scan("s = '(\\'[' + \"{\"  # (", from: PythonLineState())

        XCTAssertEqual(state, PythonLineState())
    }

    func test_should_carry_open_triple_quoted_string() {
        let state = PythonLineScanner.scan("text = '''start (", from: PythonLineState())

        XCTAssertEqual(state, PythonLineState(openTripleQuote: "'''"))
    }

    func test_should_close_triple_quoted_string_on_later_line() {
        let state = PythonLineScanner.scan(
            "end''' + f(",
            from: PythonLineState(openTripleQuote: "'''")
        )

        XCTAssertEqual(state, PythonLineState(openTripleQuote: nil, bracketDepth: 1))
    }

    func test_should_not_close_triple_quoted_string_with_other_quote() {
        let state = PythonLineScanner.scan(
            "\"\"\" # still inside",
            from: PythonLineState(openTripleQuote: "'''")
        )

        XCTAssertEqual(state.openTripleQuote, "'''")
    }
}
