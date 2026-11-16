import XCTest

@testable import Something

final class PythonSyntaxScannerTests: XCTestCase {
    private struct NamedToken: Equatable {
        let kind: PythonTokenKind
        let text: String
    }

    // Pairs each token with its text, so that a wrong range shows as wrong text.
    private func findNamedTokens(in text: String) -> [NamedToken] {
        let nsText = text as NSString
        return PythonSyntaxScanner.findTokens(in: text).map { token in
            NamedToken(kind: token.kind, text: nsText.substring(with: token.range))
        }
    }

    func test_should_find_keyword() {
        let tokens = findNamedTokens(in: "def f(): pass")

        XCTAssertEqual(tokens, [NamedToken(kind: .keyword, text: "def"), NamedToken(kind: .keyword, text: "pass")])
    }

    func test_should_treat_true_and_none_as_keywords() {
        let tokens = findNamedTokens(in: "x = True or None")

        XCTAssertEqual(tokens.map(\.text), ["True", "or", "None"])
    }

    func test_should_find_builtin() {
        let tokens = findNamedTokens(in: "print(len(x))")

        XCTAssertEqual(tokens, [NamedToken(kind: .builtin, text: "print"), NamedToken(kind: .builtin, text: "len")])
    }

    func test_should_not_mark_attribute_named_like_builtin() {
        let tokens = findNamedTokens(in: "logger.print")

        XCTAssertEqual(tokens, [])
    }

    func test_should_not_mark_identifier_that_contains_keyword() {
        let tokens = findNamedTokens(in: "define = imported")

        XCTAssertEqual(tokens, [])
    }

    func test_should_find_single_and_double_quoted_strings() {
        let tokens = findNamedTokens(in: "a = 'x' + \"y\"")

        XCTAssertEqual(tokens, [NamedToken(kind: .string, text: "'x'"), NamedToken(kind: .string, text: "\"y\"")])
    }

    func test_should_keep_escaped_quote_inside_string() {
        let tokens = findNamedTokens(in: #"s = "a\"b" + c"#)

        XCTAssertEqual(tokens, [NamedToken(kind: .string, text: #""a\"b""#)])
    }

    func test_should_include_prefix_in_string() {
        let tokens = findNamedTokens(in: "s = f'{x}' + rb'y'")

        XCTAssertEqual(tokens.map(\.text), ["f'{x}'", "rb'y'"])
    }

    func test_should_end_unclosed_string_at_end_of_line() {
        let tokens = findNamedTokens(in: "s = 'abc\nif")

        XCTAssertEqual(tokens, [NamedToken(kind: .string, text: "'abc"), NamedToken(kind: .keyword, text: "if")])
    }

    func test_should_find_comment_to_end_of_line() {
        let tokens = findNamedTokens(in: "x = 1  # note")

        XCTAssertEqual(tokens.last, NamedToken(kind: .comment, text: "# note"))
    }

    func test_should_not_start_comment_inside_string() {
        let tokens = findNamedTokens(in: "s = '# no'")

        XCTAssertEqual(tokens, [NamedToken(kind: .string, text: "'# no'")])
    }

    func test_should_find_numbers() {
        let tokens = findNamedTokens(in: "a = 42 + 3.14 + 0x1F + 1e-5 + .5")

        XCTAssertEqual(tokens.map(\.text), ["42", "3.14", "0x1F", "1e-5", ".5"])
    }

    func test_should_not_mark_digits_inside_identifier() {
        let tokens = findNamedTokens(in: "x1 = y2")

        XCTAssertEqual(tokens, [])
    }

    func test_should_find_decorator_with_dotted_name() {
        let tokens = findNamedTokens(in: "@functools.cache\ndef f(): pass")

        XCTAssertEqual(tokens.first, NamedToken(kind: .decorator, text: "@functools.cache"))
    }

    func test_should_not_mark_matrix_multiplication_as_decorator() {
        let tokens = findNamedTokens(in: "c = a @ b")

        XCTAssertEqual(tokens, [])
    }

    func test_should_mark_each_line_of_triple_quoted_string() {
        let tokens = findNamedTokens(in: "s = \"\"\"a\nif b\"\"\" or c")

        XCTAssertEqual(
            tokens,
            [
                NamedToken(kind: .string, text: "\"\"\"a"),
                NamedToken(kind: .string, text: "if b\"\"\""),
                NamedToken(kind: .keyword, text: "or"),
            ]
        )
    }

    func test_should_mark_result_line() {
        let tokens = findNamedTokens(in: "1 + 2\n# => 3")

        XCTAssertEqual(tokens.last, NamedToken(kind: .result, text: "# => 3"))
    }

    func test_should_mark_error_line() {
        let tokens = findNamedTokens(in: "1 / 0\n# !! ZeroDivisionError")

        XCTAssertEqual(tokens.last, NamedToken(kind: .error, text: "# !! ZeroDivisionError"))
    }

    func test_should_keep_result_prefix_inside_triple_quoted_string_as_string() {
        let tokens = findNamedTokens(in: "s = '''\n# => 3\n'''")

        XCTAssertEqual(
            tokens,
            [
                NamedToken(kind: .string, text: "'''"),
                NamedToken(kind: .string, text: "# => 3"),
                NamedToken(kind: .string, text: "'''"),
            ]
        )
    }

    func test_should_carry_prefixed_triple_quoted_string_across_lines() {
        let tokens = findNamedTokens(in: "s = R\"\"\"a\nif\"\"\" or b")

        XCTAssertEqual(
            tokens,
            [
                NamedToken(kind: .string, text: "R\"\"\"a"),
                NamedToken(kind: .string, text: "if\"\"\""),
                NamedToken(kind: .keyword, text: "or"),
            ]
        )
    }

    func test_should_skip_escaped_quote_inside_triple_quoted_string() {
        let tokens = findNamedTokens(in: #"s = '''a\''' or b''' and c"#)

        XCTAssertEqual(
            tokens,
            [
                NamedToken(kind: .string, text: #"'''a\''' or b'''"#),
                NamedToken(kind: .keyword, text: "and"),
            ]
        )
    }

    // The text view also breaks a line at a lone carriage return.
    func test_should_end_comment_at_carriage_return() {
        let tokens = findNamedTokens(in: "# c\rif")

        XCTAssertEqual(tokens.last, NamedToken(kind: .keyword, text: "if"))
    }

    // A character outside the Basic Multilingual Plane takes two UTF-16 units.
    func test_should_measure_ranges_in_utf16_after_wide_characters() {
        let tokens = findNamedTokens(in: "s = '\u{1F600}\u{3042}'\nif")

        XCTAssertEqual(tokens.last, NamedToken(kind: .keyword, text: "if"))
    }

    func test_should_find_non_ascii_identifier_as_plain_name() {
        let tokens = findNamedTokens(in: "\u{5024} = 1")

        XCTAssertEqual(tokens, [NamedToken(kind: .number, text: "1")])
    }

    // Swift keeps "\r\n" as one Character, which a split by Character would miss.
    func test_should_end_comment_at_carriage_return_and_line_feed() {
        let tokens = findNamedTokens(in: "# c\r\nif")

        XCTAssertEqual(tokens.last, NamedToken(kind: .keyword, text: "if"))
    }
}
