import XCTest

@testable import Something

final class ApplicationMatcherTests: XCTestCase {
    private func filterNames(_ names: [String], query: String) -> [String] {
        let applications = names.map(makeApplication)
        return ApplicationMatcher.filterApplications(applications, matching: query).map(\.name)
    }

    func test_should_return_all_sorted_by_name_when_query_is_empty() {
        let names = filterNames(["Safari", "Mail", "Calendar"], query: "")

        XCTAssertEqual(names, ["Calendar", "Mail", "Safari"])
    }

    func test_should_return_all_when_query_is_only_whitespace() {
        let names = filterNames(["Safari", "Mail"], query: "   ")

        XCTAssertEqual(names, ["Mail", "Safari"])
    }

    func test_should_ignore_case_when_matching() {
        let names = filterNames(["Safari", "Mail"], query: "SAF")

        XCTAssertEqual(names, ["Safari"])
    }

    func test_should_match_substring_in_the_middle_of_name() {
        let names = filterNames(["Activity Monitor", "Safari"], query: "moni")

        XCTAssertEqual(names, ["Activity Monitor"])
    }

    func test_should_require_every_space_separated_pattern_to_match() {
        let names = filterNames(["Visual Studio Code", "Xcode", "Visual Basic"], query: "vis code")

        XCTAssertEqual(names, ["Visual Studio Code"])
    }

    func test_should_match_patterns_in_any_order() {
        let names = filterNames(["Visual Studio Code", "Xcode"], query: "code vis")

        XCTAssertEqual(names, ["Visual Studio Code"])
    }

    func test_should_rank_prefix_match_before_other_matches() {
        let names = filterNames(["Activity Monitor", "Monitor Tool", "Mail"], query: "mon")

        XCTAssertEqual(names, ["Monitor Tool", "Activity Monitor"])
    }

    func test_should_return_empty_when_nothing_matches() {
        let names = filterNames(["Safari", "Mail"], query: "zzz")

        XCTAssertEqual(names, [])
    }
}
