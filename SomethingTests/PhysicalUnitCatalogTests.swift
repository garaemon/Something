import XCTest

@testable import Something

final class PhysicalUnitCatalogTests: XCTestCase {
    func test_should_find_a_unit_by_its_plural_name() {
        let definition = PhysicalUnitCatalog.findUnit(named: "kilometers")

        XCTAssertEqual(definition?.symbol, "km")
    }

    func test_should_find_a_unit_by_its_abbreviation() {
        let definition = PhysicalUnitCatalog.findUnit(named: "f")

        XCTAssertEqual(definition?.symbol, "\u{00B0}F")
    }

    func test_should_ignore_case_and_surrounding_space_of_a_unit_name() {
        let definition = PhysicalUnitCatalog.findUnit(named: "  Celsius ")

        XCTAssertEqual(definition?.symbol, "\u{00B0}C")
    }

    func test_should_return_nil_for_an_unknown_unit() {
        XCTAssertNil(PhysicalUnitCatalog.findUnit(named: "blorbs"))
    }

    func test_should_give_every_alias_to_one_unit_only() {
        let allAliases = PhysicalUnitCatalog.definitions.flatMap(\.aliases)

        XCTAssertEqual(Set(allAliases).count, allAliases.count)
    }
}
