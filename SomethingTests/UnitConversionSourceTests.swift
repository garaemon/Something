import XCTest

@testable import Something

final class UnitConversionSourceTests: XCTestCase {
    func test_should_list_the_converted_value_with_its_unit() {
        let source = UnitConversionSource(copyText: { _ in })

        let names = source.makeCandidates(matching: "10 km in miles").map(\.name)

        XCTAssertEqual(names, ["= 6.21371192237 mi"])
    }

    func test_should_list_nothing_for_a_non_conversion() {
        let source = UnitConversionSource(copyText: { _ in })

        XCTAssertTrue(source.makeCandidates(matching: "10 + 30").isEmpty)
    }

    func test_should_tag_the_result_as_unit() {
        let source = UnitConversionSource(copyText: { _ in })

        let kinds = source.makeCandidates(matching: "1 km in m").map(\.kind)

        XCTAssertEqual(kinds, [.unit])
    }

    func test_should_copy_the_result_on_default_action() {
        var copiedTexts: [String] = []
        let source = UnitConversionSource(copyText: { copiedTexts.append($0) })

        source.makeCandidates(matching: "1 km in m").first?.defaultAction?.perform()

        XCTAssertEqual(copiedTexts, ["1000 m"])
    }
}
