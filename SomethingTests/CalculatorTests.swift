import XCTest

@testable import Something

final class CalculatorTests: XCTestCase {
    func test_should_add_two_numbers() {
        XCTAssertEqual(Calculator.evaluate("10 + 30"), 40)
    }

    func test_should_multiply_before_adding() {
        XCTAssertEqual(Calculator.evaluate("2 + 3 * 4"), 14)
    }

    func test_should_evaluate_parentheses_first() {
        XCTAssertEqual(Calculator.evaluate("(2 + 3) * 4"), 20)
    }

    func test_should_subtract_from_left_to_right() {
        XCTAssertEqual(Calculator.evaluate("10 - 3 - 2"), 5)
    }

    func test_should_divide_into_a_fraction() {
        XCTAssertEqual(Calculator.evaluate("1 / 4"), 0.25)
    }

    func test_should_negate_with_unary_minus() {
        XCTAssertEqual(Calculator.evaluate("-3 * -2"), 6)
    }

    func test_should_raise_power_from_right_to_left() {
        XCTAssertEqual(Calculator.evaluate("2 ^ 3 ^ 2"), 512)
    }

    func test_should_take_remainder() {
        XCTAssertEqual(Calculator.evaluate("10 % 4"), 2)
    }

    func test_should_accept_multiplication_and_division_signs() {
        XCTAssertEqual(Calculator.evaluate("6 × 4 ÷ 3"), 8)
    }

    func test_should_parse_decimals_without_spaces() {
        XCTAssertEqual(Calculator.evaluate("1.5*2"), 3)
    }

    // A bare number such as "2024" is more likely a search than a sum.
    func test_should_reject_a_lone_number() {
        XCTAssertNil(Calculator.evaluate("2024"))
    }

    func test_should_reject_a_trailing_operator() {
        XCTAssertNil(Calculator.evaluate("10 +"))
    }

    func test_should_reject_unbalanced_parentheses() {
        XCTAssertNil(Calculator.evaluate("(1 + 2"))
    }

    func test_should_reject_words() {
        XCTAssertNil(Calculator.evaluate("safari"))
    }

    func test_should_reject_division_by_zero() {
        XCTAssertNil(Calculator.evaluate("1 / 0"))
    }

    func test_should_format_an_integral_result_without_decimals() {
        XCTAssertEqual(Calculator.formatResult(40), "40")
    }

    func test_should_format_a_fraction_without_float_noise() {
        XCTAssertEqual(Calculator.formatResult(0.1 + 0.2), "0.3")
    }

    func test_should_format_a_negative_result() {
        XCTAssertEqual(Calculator.formatResult(-2.5), "-2.5")
    }
}
