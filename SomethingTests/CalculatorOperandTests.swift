import XCTest

@testable import Something

final class CalculatorOperandTests: XCTestCase {
    func test_should_evaluate_a_bare_number_as_an_operand() {
        XCTAssertEqual(Calculator.evaluateOperand("2024"), 2024)
    }

    func test_should_evaluate_a_negative_number_as_an_operand() {
        XCTAssertEqual(Calculator.evaluateOperand("-5"), -5)
    }

    func test_should_evaluate_an_expression_as_an_operand() {
        XCTAssertEqual(Calculator.evaluateOperand("1 + 2"), 3)
    }

    func test_should_reject_text_as_an_operand() {
        XCTAssertNil(Calculator.evaluateOperand("abc"))
    }

    func test_should_keep_rejecting_a_bare_number_in_evaluate() {
        XCTAssertNil(Calculator.evaluate("2024"))
    }
}
