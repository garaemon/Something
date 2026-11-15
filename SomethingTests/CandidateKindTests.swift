import XCTest

@testable import Something

/// Every source tags its rows with a kind, so that the launcher can tell a
/// window of Safari apart from the Safari application itself.
final class CandidateKindTests: XCTestCase {
    func test_should_tag_window_candidates_as_window() {
        let source = WindowSource(windows: [makeWindow("Safari", "GitHub")], raiseWindow: { _ in })

        let kinds = source.makeCandidates(matching: "").map(\.kind)

        XCTAssertEqual(kinds, [.window])
    }

    func test_should_tag_application_candidates_as_application() {
        let source = ApplicationSource(applications: [makeApplication("Safari")], launchApplication: { _ in })

        let kinds = source.makeCandidates(matching: "").map(\.kind)

        XCTAssertEqual(kinds, [.application])
    }

    func test_should_tag_repository_candidates_as_repository() {
        let source = RepositorySource(
            repositories: [makeRepository("github.com/owner/name")], openRepository: { _ in })

        let kinds = source.makeCandidates(matching: "").map(\.kind)

        XCTAssertEqual(kinds, [.repository])
    }

    func test_should_tag_web_search_candidates_as_web_search() {
        let source = WebSearchSource(engines: WebSearchEngine.launcherEngines, openURL: { _ in })

        let kinds = Set(source.makeCandidates(matching: "swift").map(\.kind))

        XCTAssertEqual(kinds, [.webSearch])
    }

    func test_should_tag_settings_candidate_as_settings() {
        let source = SettingsSource(openSettings: {})

        let kinds = source.makeCandidates(matching: "settings").map(\.kind)

        XCTAssertEqual(kinds, [.settings])
    }

    func test_should_give_every_kind_a_distinct_label() {
        let kinds: [LauncherCandidateKind] = [.window, .application, .repository, .webSearch, .settings]

        let labels = Set(kinds.map(\.label))

        XCTAssertEqual(labels.count, kinds.count)
    }
}
