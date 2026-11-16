import XCTest

@testable import Something

final class ScratchSourceTests: XCTestCase {
    func test_should_list_scratch_for_scratch_query() {
        let source = ScratchSource(openScratch: {})

        let names = source.makeCandidates(matching: "scra").map(\.name)

        XCTAssertEqual(names, [ScratchSource.candidateName])
    }

    func test_should_list_scratch_for_python_query() {
        let source = ScratchSource(openScratch: {})

        let candidates = source.makeCandidates(matching: "python")

        XCTAssertEqual(candidates.count, 1)
    }

    func test_should_list_nothing_for_empty_query() {
        let source = ScratchSource(openScratch: {})

        let candidates = source.makeCandidates(matching: "")

        XCTAssertTrue(candidates.isEmpty)
    }

    func test_should_list_nothing_for_unrelated_query() {
        let source = ScratchSource(openScratch: {})

        let candidates = source.makeCandidates(matching: "safari")

        XCTAssertTrue(candidates.isEmpty)
    }

    func test_should_tag_scratch_candidate_as_scratch() {
        let source = ScratchSource(openScratch: {})

        let kinds = source.makeCandidates(matching: "scratch").map(\.kind)

        XCTAssertEqual(kinds, [.scratch])
    }

    func test_should_open_scratch_on_default_action() {
        var openCount = 0
        let source = ScratchSource(openScratch: { openCount += 1 })

        source.makeCandidates(matching: "scratch").first?.defaultAction?.perform()

        XCTAssertEqual(openCount, 1)
    }
}
