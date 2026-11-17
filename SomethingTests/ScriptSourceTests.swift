import XCTest

@testable import Something

final class ScriptSourceTests: XCTestCase {
    private func makeItem(
        _ title: String, source: String = "demo", generation: Int = 1, action: Int? = 0
    ) -> ScriptItem {
        ScriptItem(generation: generation, source: source, title: title, action: action)
    }

    func test_should_narrow_items_by_title() {
        let source = ScriptSource(
            items: [makeItem("Safari — GitHub"), makeItem("Code — scratch.py")],
            runAction: { _, _ in }
        )

        let names = source.makeCandidates(matching: "git").map(\.name)

        XCTAssertEqual(names, ["Safari — GitHub"])
    }

    func test_should_list_every_item_for_an_empty_query() {
        let source = ScriptSource(
            items: [makeItem("b"), makeItem("a")], runAction: { _, _ in })

        let names = source.makeCandidates(matching: "").map(\.name)

        XCTAssertEqual(names, ["a", "b"])
    }

    func test_should_yield_candidate_without_actions_for_item_without_action() throws {
        let source = ScriptSource(items: [makeItem("plain", action: nil)], runAction: { _, _ in })

        let candidate = try XCTUnwrap(source.makeCandidates(matching: "").first)

        XCTAssertTrue(candidate.actions.isEmpty)
    }

    func test_should_run_action_with_generation_and_index_of_the_item() throws {
        var calls: [[Int]] = []
        let source = ScriptSource(
            items: [makeItem("row", generation: 4, action: 2)],
            runAction: { generation, index in calls.append([generation, index]) }
        )
        let candidate = try XCTUnwrap(source.makeCandidates(matching: "").first)

        candidate.defaultAction?.perform()

        XCTAssertEqual(calls, [[4, 2]])
    }

    func test_should_tag_candidates_as_script_with_a_symbol_icon() throws {
        let source = ScriptSource(items: [makeItem("row")], runAction: { _, _ in })

        let candidate = try XCTUnwrap(source.makeCandidates(matching: "").first)

        XCTAssertEqual(candidate.kind, .script)
        XCTAssertEqual(candidate.icon, .systemSymbol("curlybraces"))
    }

    func test_should_keep_candidate_identity_across_generations() throws {
        let older = ScriptSource(items: [makeItem("row", generation: 1)], runAction: { _, _ in })
        let newer = ScriptSource(items: [makeItem("row", generation: 2)], runAction: { _, _ in })

        let olderID = try XCTUnwrap(older.makeCandidates(matching: "").first).id
        let newerID = try XCTUnwrap(newer.makeCandidates(matching: "").first).id

        XCTAssertEqual(olderID, newerID)
    }

    func test_should_tell_apart_rows_with_the_same_title() {
        let source = ScriptSource(
            items: [makeItem("same", action: 0), makeItem("same", action: 1)],
            runAction: { _, _ in }
        )

        let ids = Set(source.makeCandidates(matching: "").map(\.id))

        XCTAssertEqual(ids.count, 2)
    }
}
