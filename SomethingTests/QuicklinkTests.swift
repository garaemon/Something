import XCTest

@testable import Something

final class QuicklinkTests: XCTestCase {
    func test_should_fill_query_placeholder_percent_encoded() {
        let quicklink = Quicklink(name: "gh", url: "https://github.com/search?q={query}")

        let url = quicklink.makeURL(query: "swift ui&a+b")

        XCTAssertEqual(url?.absoluteString, "https://github.com/search?q=swift%20ui%26a%2Bb")
    }

    func test_should_keep_template_without_placeholder() {
        let quicklink = Quicklink(name: "home", url: "file:///Users/me")

        XCTAssertEqual(quicklink.makeURL(query: "ignored")?.absoluteString, "file:///Users/me")
    }

    func test_should_accept_custom_scheme() {
        let quicklink = Quicklink(name: "note", url: "obsidian://search?query={query}")

        XCTAssertEqual(quicklink.makeURL(query: "a b")?.scheme, "obsidian")
    }

    func test_should_return_nil_for_malformed_template() {
        let quicklink = Quicklink(name: "bad", url: "http://exa mple.com/{query}")

        XCTAssertNil(quicklink.makeURL(query: "x"))
    }

    func test_should_decode_application_as_optional() throws {
        let json = Data(
            """
            [{"name": "a", "url": "x://"},
             {"name": "b", "url": "y://", "application": "com.apple.Safari"}]
            """.utf8)

        let quicklinks = try JSONDecoder().decode([Quicklink].self, from: json)

        XCTAssertEqual(quicklinks.map(\.application), [nil, "com.apple.Safari"])
    }
}

final class QuicklinkStoreTests: XCTestCase {
    private func makeStore(contents: String?) throws -> QuicklinkStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("quicklinks.json")
        if let contents { try contents.write(to: fileURL, atomically: true, encoding: .utf8) }
        return QuicklinkStore(fileURL: fileURL)
    }

    func test_should_load_nothing_when_file_is_missing() throws {
        let store = try makeStore(contents: nil)

        XCTAssertEqual(store.load(), .loaded([]))
    }

    func test_should_load_quicklinks_from_file() throws {
        let store = try makeStore(contents: #"[{"name": "gh", "url": "https://github.com"}]"#)

        XCTAssertEqual(store.load(), .loaded([Quicklink(name: "gh", url: "https://github.com")]))
    }

    func test_should_report_parse_failure() throws {
        let store = try makeStore(contents: "[{")

        guard case .failed = store.load() else { return XCTFail("expected failure") }
    }

    func test_should_name_the_missing_key_in_failure() throws {
        let store = try makeStore(contents: #"[{"name": "gh"}]"#)

        guard case .failed(let reason) = store.load() else { return XCTFail("expected failure") }

        XCTAssertTrue(reason.contains("url"), reason)
    }
}

final class QuicklinkSourceTests: XCTestCase {
    private let github = Quicklink(name: "gh", url: "https://github.com/search?q={query}")

    private func makeSource(
        _ result: QuicklinkLoadResult,
        open: @escaping (URL, String?) -> Void = { _, _ in }
    ) -> QuicklinkSource {
        QuicklinkSource(loadResult: result, openQuicklink: open)
    }

    func test_should_list_nothing_for_empty_query() {
        XCTAssertTrue(makeSource(.loaded([github])).makeCandidates(matching: "").isEmpty)
    }

    func test_should_list_quicklink_when_first_word_equals_name() {
        let candidates = makeSource(.loaded([github])).makeCandidates(matching: "GH something")

        XCTAssertEqual(candidates.map(\.kind), [.quicklink])
    }

    func test_should_list_quicklink_for_name_prefix_alone() {
        XCTAssertEqual(makeSource(.loaded([github])).makeCandidates(matching: "g").count, 1)
    }

    func test_should_not_list_quicklink_for_other_first_word() {
        XCTAssertTrue(makeSource(.loaded([github])).makeCandidates(matching: "g x").isEmpty)
    }

    func test_should_open_filled_url_with_application() {
        var opened: (URL, String?)?
        let quicklink = Quicklink(name: "gh", url: "https://x.test/{query}", application: "app.id")
        let source = makeSource(.loaded([quicklink]), open: { opened = ($0, $1) })

        source.makeCandidates(matching: "gh a b").first?.defaultAction?.perform()

        XCTAssertEqual(opened?.0.absoluteString, "https://x.test/a%20b")
        XCTAssertEqual(opened?.1, "app.id")
    }

    func test_should_list_error_row_without_action_on_empty_query() {
        let candidates = makeSource(.failed("bad json")).makeCandidates(matching: "")

        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates[0].name.contains("bad json"))
        XCTAssertNil(candidates[0].defaultAction)
    }

    func test_should_list_error_row_for_non_empty_query() {
        let candidates = makeSource(.failed("bad json")).makeCandidates(matching: "safari")

        XCTAssertEqual(candidates.count, 1)
    }

    func test_should_list_row_without_action_for_malformed_template() {
        let broken = Quicklink(name: "bad", url: "http://exa mple.com/{query}")

        let candidates = makeSource(.loaded([broken])).makeCandidates(matching: "bad x")

        XCTAssertEqual(candidates.count, 1)
        XCTAssertNil(candidates[0].defaultAction)
    }

    func test_should_list_nothing_for_missing_file_on_empty_query() {
        XCTAssertTrue(makeSource(.loaded([])).makeCandidates(matching: "").isEmpty)
    }
}
