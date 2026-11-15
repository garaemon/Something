import XCTest

@testable import Something

final class PythonInterpreterTests: XCTestCase {
    private let interpreter = PythonInterpreter.shared

    override func setUp() {
        super.setUp()
        interpreter.reset()
    }

    func test_should_capture_printed_output() {
        let result = interpreter.run(PythonBlock(lastStatement: "print('hello')"))

        XCTAssertEqual(result.output, "hello\n")
    }

    func test_should_echo_value_of_last_expression() {
        let result = interpreter.run(PythonBlock(lastStatement: "1 + 2"))

        XCTAssertEqual(result.output, "3\n")
    }

    func test_should_not_echo_none() {
        let result = interpreter.run(PythonBlock(lastStatement: "None"))

        XCTAssertEqual(result.output, "")
    }

    func test_should_echo_only_the_last_statement() {
        let block = PythonBlock(leadingSource: "x = 2\nx * 10", lastStatement: "x + 1")

        let result = interpreter.run(block)

        XCTAssertEqual(result.output, "3\n")
    }

    func test_should_keep_variables_between_runs() {
        _ = interpreter.run(PythonBlock(lastStatement: "x = 21"))

        let result = interpreter.run(PythonBlock(lastStatement: "x * 2"))

        XCTAssertEqual(result.output, "42\n")
    }

    func test_should_import_math() {
        let block = PythonBlock(leadingSource: "import math", lastStatement: "math.sqrt(16)")

        let result = interpreter.run(block)

        XCTAssertEqual(result.output, "4.0\n")
    }

    func test_should_report_no_error_on_success() {
        let result = interpreter.run(PythonBlock(lastStatement: "1 + 2"))

        XCTAssertNil(result.errorMessage)
    }

    func test_should_report_last_line_of_traceback_as_error() {
        let result = interpreter.run(PythonBlock(lastStatement: "1 / 0"))

        XCTAssertEqual(result.errorMessage?.hasPrefix("ZeroDivisionError:"), true)
    }

    func test_should_keep_output_printed_before_error() {
        let block = PythonBlock(leadingSource: "print('before')", lastStatement: "1 / 0")

        let result = interpreter.run(block)

        XCTAssertEqual(result.output, "before\n")
    }

    func test_should_skip_last_statement_when_leading_source_fails() {
        let block = PythonBlock(leadingSource: "1 / 0", lastStatement: "print('after')")

        let result = interpreter.run(block)

        XCTAssertEqual(result.output, "")
    }

    func test_should_report_syntax_error() {
        let result = interpreter.run(PythonBlock(lastStatement: "def"))

        XCTAssertEqual(result.errorMessage?.hasPrefix("SyntaxError"), true)
    }

    func test_should_run_again_after_error() {
        _ = interpreter.run(PythonBlock(lastStatement: "1 / 0"))

        let result = interpreter.run(PythonBlock(lastStatement: "1 + 1"))

        XCTAssertEqual(result, PythonRunResult(output: "2\n", errorMessage: nil))
    }

    func test_should_stop_infinite_loop_after_timeout() {
        let block = PythonBlock(lastStatement: "while True:\n    pass\n")

        let result = interpreter.run(block, timeoutMilliseconds: 200)

        XCTAssertEqual(result.errorMessage?.hasPrefix("TimeoutError"), true)
    }

    func test_should_forget_variables_after_reset() {
        _ = interpreter.run(PythonBlock(lastStatement: "x = 1"))
        interpreter.reset()

        let result = interpreter.run(PythonBlock(lastStatement: "x"))

        XCTAssertEqual(result.errorMessage?.hasPrefix("NameError"), true)
    }

    func test_should_capture_output_after_reset() {
        interpreter.reset()

        let result = interpreter.run(PythonBlock(lastStatement: "print('again')"))

        XCTAssertEqual(result.output, "again\n")
    }
}
