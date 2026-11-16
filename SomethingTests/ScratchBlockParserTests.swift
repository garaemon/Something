import XCTest

@testable import Something

final class ScratchBlockParserTests: XCTestCase {
    private func findBlocks(_ text: String) -> [ScratchBlock] {
        ScratchBlockParser.findBlocks(in: text.components(separatedBy: "\n"))
    }

    func test_should_find_paragraphs_as_blocks() {
        let blocks = findBlocks("x = 1\ny = 2\n\nprint(x)")

        XCTAssertEqual(blocks.map(\.lineRange), [0..<2, 3..<4])
    }

    func test_should_keep_blank_lines_inside_indented_body_in_one_block() {
        let blocks = findBlocks("def f():\n    a = 1\n\n    return a\nf()")

        XCTAssertEqual(blocks.map(\.lineRange), [0..<5])
    }

    func test_should_skip_paragraph_of_only_comments() {
        let blocks = findBlocks("# note\n\nx = 1")

        XCTAssertEqual(blocks.map(\.lineRange), [2..<3])
    }

    func test_should_include_output_lines_after_block() {
        let blocks = findBlocks("1 + 2\n# => 3\n\nx")

        XCTAssertEqual(blocks.first?.outputRange, 1..<2)
    }

    func test_should_end_block_at_output_line() {
        let blocks = findBlocks("1 + 2\n# => 3\n2 + 3")

        XCTAssertEqual(blocks.map(\.lineRange), [0..<1, 2..<3])
    }

    func test_should_find_block_of_cursor_on_output_line() {
        let lines = ["1 + 2", "# => 3"]

        let block = ScratchBlockParser.findBlock(in: lines, containingLine: 1)

        XCTAssertEqual(block?.lineRange, 0..<1)
    }

    func test_should_find_no_block_on_blank_line() {
        let lines = ["x = 1", "", "y = 2"]

        let block = ScratchBlockParser.findBlock(in: lines, containingLine: 1)

        XCTAssertNil(block)
    }

    func test_should_split_last_top_level_statement() {
        let source = ScratchBlockParser.makePythonBlock(from: ["x = 2", "x * 3"])

        XCTAssertEqual(source, PythonBlock(leadingSource: "x = 2", lastStatement: "x * 3"))
    }

    func test_should_keep_compound_statement_with_else_as_last() {
        let lines = ["x = 1", "if x:", "    1", "else:", "    2"]

        let source = ScratchBlockParser.makePythonBlock(from: lines)

        XCTAssertEqual(source.lastStatement, "if x:\n    1\nelse:\n    2")
    }

    func test_should_keep_decorated_function_as_last() {
        let lines = ["import functools", "@functools.cache", "def f():", "    return 1"]

        let source = ScratchBlockParser.makePythonBlock(from: lines)

        XCTAssertEqual(source.lastStatement, "@functools.cache\ndef f():\n    return 1")
    }

    func test_should_keep_bracket_continuation_lines_in_last_statement() {
        let lines = ["total = sum([", "1,", "2,", "])"]

        let source = ScratchBlockParser.makePythonBlock(from: lines)

        XCTAssertEqual(source.lastStatement, "total = sum([\n1,\n2,\n])")
    }

    func test_should_ignore_brackets_in_strings_and_comments() {
        let lines = ["s = '('  # (", "s"]

        let source = ScratchBlockParser.makePythonBlock(from: lines)

        XCTAssertEqual(source.lastStatement, "s")
    }

    func test_should_format_output_as_result_lines() {
        let result = PythonRunResult(output: "a\nb\n", errorMessage: nil)

        let lines = ScratchBlockParser.formatResult(result)

        XCTAssertEqual(lines, ["# => a", "# => b"])
    }

    func test_should_format_error_after_output() {
        let result = PythonRunResult(output: "a\n", errorMessage: "ValueError: x\ny")

        let lines = ScratchBlockParser.formatResult(result)

        XCTAssertEqual(lines, ["# => a", "# !! ValueError: x", "# !! y"])
    }

    func test_should_format_empty_output_as_no_lines() {
        let result = PythonRunResult(output: "", errorMessage: nil)

        let lines = ScratchBlockParser.formatResult(result)

        XCTAssertEqual(lines, [])
    }

    func test_should_keep_blank_line_inside_output() {
        let result = PythonRunResult(output: "a\n\nb\n", errorMessage: nil)

        let lines = ScratchBlockParser.formatResult(result)

        XCTAssertEqual(lines, ["# => a", "# => ", "# => b"])
    }

    func test_should_start_statement_at_identifier_that_begins_with_keyword() {
        let lines = ["else_count = 1", "else_count"]

        let source = ScratchBlockParser.makePythonBlock(from: lines)

        XCTAssertEqual(source.lastStatement, "else_count")
    }

    func test_should_start_statement_at_case_in_column_zero() {
        let lines = ["case = 1", "case"]

        let source = ScratchBlockParser.makePythonBlock(from: lines)

        XCTAssertEqual(source.lastStatement, "case")
    }
}
