import XCTest

@testable import Something

final class CalculatorSourceTests: XCTestCase {
    func test_should_list_the_result_of_an_expression() {
        let source = CalculatorSource(copyText: { _ in })

        let names = source.makeCandidates(matching: "10 + 30").map(\.name)

        XCTAssertEqual(names, ["= 40"])
    }

    func test_should_list_nothing_for_a_non_expression() {
        let source = CalculatorSource(copyText: { _ in })

        let candidates = source.makeCandidates(matching: "safari")

        XCTAssertTrue(candidates.isEmpty)
    }

    func test_should_tag_the_result_as_calculator() {
        let source = CalculatorSource(copyText: { _ in })

        let kinds = source.makeCandidates(matching: "1 + 1").map(\.kind)

        XCTAssertEqual(kinds, [.calculator])
    }

    func test_should_copy_the_result_on_default_action() {
        var copiedTexts: [String] = []
        let source = CalculatorSource(copyText: { copiedTexts.append($0) })

        source.makeCandidates(matching: "1 / 4").first?.defaultAction?.perform()

        XCTAssertEqual(copiedTexts, ["0.25"])
    }
}
