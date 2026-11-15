import XCTest

@testable import Something

final class WebSearchTests: XCTestCase {
    func test_should_build_google_search_url_for_plain_query() {
        let search = WebSearch(engine: .google, query: "swift")

        XCTAssertEqual(search.url?.absoluteString, "https://www.google.com/search?q=swift")
    }

    func test_should_build_google_ai_mode_url_with_udm_parameter() {
        let search = WebSearch(engine: .googleAIMode, query: "swift")

        XCTAssertEqual(search.url?.absoluteString, "https://www.google.com/search?udm=50&q=swift")
    }

    func test_should_preserve_query_with_reserved_characters() {
        let query = "a b&c+d#e=f"
        let search = WebSearch(engine: .google, query: query)

        XCTAssertEqual(decodeQueryParameter(of: search.url), query)
    }

    func test_should_preserve_japanese_query() {
        let query = "\u{6771}\u{4EAC} \u{5929}\u{6C17}"
        let search = WebSearch(engine: .google, query: query)

        XCTAssertEqual(decodeQueryParameter(of: search.url), query)
    }

    func test_should_encode_plus_so_that_google_does_not_read_it_as_space() {
        let search = WebSearch(engine: .google, query: "c++")

        XCTAssertEqual(search.url?.absoluteString, "https://www.google.com/search?q=c%2B%2B")
    }

    func test_should_show_engine_name_and_query_as_title() {
        let search = WebSearch(engine: .google, query: "swift")

        XCTAssertEqual(search.title, "Search Google: swift")
    }

    private func decodeQueryParameter(of url: URL?) -> String? {
        guard let url else { return nil }
        // Decode the way a server does: `+` means a space, so a correct
        // encoder must have escaped every literal plus as %2B.
        let rawQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .percentEncodedQueryItems?.first { $0.name == "q" }?.value
        return rawQuery?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    }
}
