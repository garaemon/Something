import XCTest

@testable import Something

final class UnitConversionTests: XCTestCase {
    func test_should_convert_kilometers_to_miles() throws {
        let result = try XCTUnwrap(UnitConversion.convert("10 km in miles"))

        XCTAssertEqual(result.valueText, "6.21371192237")
        XCTAssertEqual(result.unitSymbol, "mi")
    }

    func test_should_convert_fahrenheit_to_celsius() throws {
        let result = try XCTUnwrap(UnitConversion.convert("212 f to c"))

        XCTAssertEqual(result.valueText, "100")
        XCTAssertEqual(result.unitSymbol, "\u{00B0}C")
    }

    func test_should_accept_as_for_the_separator() {
        XCTAssertEqual(UnitConversion.convert("1 km as m")?.valueText, "1000")
    }

    func test_should_accept_an_arithmetic_expression_as_the_number() {
        XCTAssertEqual(UnitConversion.convert("(2 + 3) * 2 km to m")?.valueText, "10000")
    }

    func test_should_accept_a_number_glued_to_its_unit() {
        XCTAssertEqual(UnitConversion.convert("2km in m")?.valueText, "2000")
    }

    func test_should_accept_a_negative_number() {
        XCTAssertEqual(UnitConversion.convert("-40 c in f")?.valueText, "-40")
    }

    func test_should_read_in_as_inches_before_the_separator() {
        XCTAssertEqual(UnitConversion.convert("10 in in cm")?.valueText, "25.4")
    }

    func test_should_convert_a_unit_with_a_space_in_its_name() {
        XCTAssertEqual(UnitConversion.convert("1 fl oz to ml")?.valueText, "29.5735295625")
    }

    func test_should_convert_speed() {
        XCTAssertEqual(UnitConversion.convert("36 km/h to m/s")?.valueText, "10")
    }

    func test_should_convert_decimal_and_binary_data_sizes() {
        XCTAssertEqual(UnitConversion.convert("1 gib in mb")?.valueText, "1073.741824")
    }

    func test_should_convert_days_to_hours() {
        XCTAssertEqual(UnitConversion.convert("2 days in hours")?.valueText, "48")
    }

    func test_should_convert_mass_volume_and_area() {
        XCTAssertEqual(UnitConversion.convert("1 kg to g")?.valueText, "1000")
        XCTAssertEqual(UnitConversion.convert("1 l to ml")?.valueText, "1000")
        XCTAssertEqual(UnitConversion.convert("1 ha to m2")?.valueText, "10000")
    }

    func test_should_use_exact_coefficients_for_customary_units() {
        XCTAssertEqual(UnitConversion.convert("1 lb to g")?.valueText, "453.59237")
        XCTAssertEqual(UnitConversion.convert("1 gal to l")?.valueText, "3.785411784")
        XCTAssertEqual(UnitConversion.convert("1 cup to ml")?.valueText, "236.5882365")
    }

    func test_should_reject_mismatched_dimensions() {
        XCTAssertNil(UnitConversion.convert("10 km in kg"))
    }

    func test_should_reject_an_unknown_unit() {
        XCTAssertNil(UnitConversion.convert("10 km in blorbs"))
    }

    func test_should_reject_a_query_without_a_number() {
        XCTAssertNil(UnitConversion.convert("km in miles"))
    }

    func test_should_reject_a_query_without_a_separator() {
        XCTAssertNil(UnitConversion.convert("10 km miles"))
    }

    func test_should_reject_a_plain_search() {
        XCTAssertNil(UnitConversion.convert("safari"))
    }
}
