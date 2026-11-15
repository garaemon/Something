import XCTest

@testable import Something

@MainActor
final class LauncherViewModelTests: XCTestCase {
    private func makeViewModel(
        _ names: [String], onLaunch: @escaping (LaunchableApplication) -> Void = { _ in }
    ) -> LauncherViewModel {
        LauncherViewModel(sources: [
            ApplicationSource(applications: names.map(makeApplication), launchApplication: onLaunch)
        ])
    }

    private func makeApplicationSource(_ names: [String]) -> ApplicationSource {
        ApplicationSource(applications: names.map(makeApplication), launchApplication: { _ in })
    }

    func test_should_show_all_applications_initially() {
        let viewModel = makeViewModel(["Safari", "Mail"])

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Mail", "Safari"])
    }

    func test_should_narrow_candidates_when_query_changes() {
        let viewModel = makeViewModel(["Safari", "Mail"])

        viewModel.query = "saf"

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Safari"])
    }

    func test_should_select_first_candidate_initially() {
        let viewModel = makeViewModel(["Safari", "Mail"])

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Mail")
    }

    func test_should_move_selection_down() {
        let viewModel = makeViewModel(["Safari", "Mail"])

        viewModel.moveSelection(by: 1)

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Safari")
    }

    func test_should_stop_at_last_candidate_when_moving_past_the_end() {
        let viewModel = makeViewModel(["Safari", "Mail"])

        viewModel.moveSelection(by: 5)

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Safari")
    }

    func test_should_stop_at_first_candidate_when_moving_before_the_start() {
        let viewModel = makeViewModel(["Safari", "Mail"])

        viewModel.moveSelection(by: -10)

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Mail")
    }

    func test_should_reset_selection_to_first_when_query_changes() {
        let viewModel = makeViewModel(["Safari", "Mail", "Messages"])
        viewModel.moveSelection(by: 2)

        viewModel.query = "m"

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Mail")
    }

    func test_should_have_no_selection_when_nothing_matches() {
        let viewModel = makeViewModel(["Safari"])

        viewModel.query = "zzz"

        XCTAssertNil(viewModel.selectedCandidate)
    }

    func test_should_show_replaced_applications_narrowed_by_current_query() {
        let viewModel = makeViewModel([])
        viewModel.query = "saf"

        viewModel.replaceSource(makeApplicationSource(["Safari", "Mail"]))

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Safari"])
    }

    func test_should_keep_selected_candidate_when_applications_are_replaced() {
        let viewModel = makeViewModel(["Mail", "Safari"])
        viewModel.moveSelection(by: 1)

        viewModel.replaceSource(makeApplicationSource(["Calendar", "Mail", "Safari"]))

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Safari")
    }

    func test_should_select_first_candidate_when_selected_candidate_disappears() {
        let viewModel = makeViewModel(["Mail", "Safari"])
        viewModel.moveSelection(by: 1)

        viewModel.replaceSource(makeApplicationSource(["Calendar", "Mail"]))

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Calendar")
    }

    func test_should_ignore_replacement_for_a_source_it_does_not_list() {
        let viewModel = makeViewModel(["Mail"])

        viewModel.replaceSource(RepositorySource(repositories: [makeRepository("github.com/a/b")]))

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Mail"])
    }

    func test_should_keep_selection_index_when_moving_without_candidates() {
        let viewModel = makeViewModel(["Safari"])
        viewModel.query = "zzz"

        viewModel.moveSelection(by: 1)

        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func test_should_report_activation_when_a_candidate_is_selected() {
        let viewModel = makeViewModel(["Safari"])

        let didActivate = viewModel.activateSelectedCandidate()

        XCTAssertTrue(didActivate)
    }

    func test_should_report_no_activation_when_nothing_is_selected() {
        let viewModel = makeViewModel(["Safari"])
        viewModel.query = "zzz"

        let didActivate = viewModel.activateSelectedCandidate()

        XCTAssertFalse(didActivate)
    }

    func test_should_select_clicked_candidate() {
        let viewModel = makeViewModel(["Mail", "Safari"])
        let clickedCandidate = makeApplicationSource(["Safari"]).makeCandidates(matching: "")[0]

        viewModel.selectCandidate(clickedCandidate)

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Safari")
    }

    func test_should_keep_selection_when_selecting_candidate_not_in_candidates() {
        let viewModel = makeViewModel(["Mail", "Safari"])
        let missingCandidate = makeApplicationSource(["Calendar"]).makeCandidates(matching: "")[0]

        viewModel.selectCandidate(missingCandidate)

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Mail")
    }

    func test_should_launch_selected_application() {
        var launchedName: String?
        let viewModel = makeViewModel(["Safari", "Mail"]) { launchedName = $0.name }
        viewModel.moveSelection(by: 1)

        viewModel.activateSelectedCandidate()

        XCTAssertEqual(launchedName, "Safari")
    }

    func test_should_not_launch_when_nothing_is_selected() {
        var launchCount = 0
        let viewModel = makeViewModel(["Safari"]) { _ in launchCount += 1 }
        viewModel.query = "zzz"

        viewModel.activateSelectedCandidate()

        XCTAssertEqual(launchCount, 0)
    }

    // SwiftUI's TextField writes the unchanged text back to its binding, for
    // example on Return, which used to send the highlight back to the top.
    func test_should_keep_selection_when_query_is_set_to_the_same_value() {
        let viewModel = makeViewModel(["Mail", "Safari"])
        viewModel.query = "a"
        viewModel.moveSelection(by: 1)

        viewModel.query = "a"

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Safari")
    }

    private func makeViewModel(
        applications applicationNames: [String], windows: [SwitchableWindow],
        onRaise: @escaping (SwitchableWindow) -> Void = { _ in }
    ) -> LauncherViewModel {
        LauncherViewModel(sources: [
            WindowSource(windows: windows, raiseWindow: onRaise),
            makeApplicationSource(applicationNames),
        ])
    }

    func test_should_list_windows_before_applications() {
        let viewModel = makeViewModel(applications: ["Mail"], windows: [makeWindow("Safari", "GitHub")])

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Safari — GitHub", "Mail"])
    }

    func test_should_narrow_windows_by_title() {
        let viewModel = makeViewModel(
            applications: [], windows: [makeWindow("Safari", "GitHub"), makeWindow("Safari", "News")])

        viewModel.query = "git"

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Safari — GitHub"])
    }

    func test_should_narrow_windows_by_application_name() {
        let viewModel = makeViewModel(
            applications: [], windows: [makeWindow("Safari", "GitHub"), makeWindow("Mail", "Inbox")])

        viewModel.query = "saf"

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Safari — GitHub"])
    }

    func test_should_show_replaced_windows_narrowed_by_current_query() {
        let viewModel = makeViewModel(applications: [], windows: [])
        viewModel.query = "git"

        viewModel.replaceSource(
            WindowSource(windows: [makeWindow("Safari", "GitHub"), makeWindow("Mail", "Inbox")]))

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Safari — GitHub"])
    }

    func test_should_keep_selected_candidate_when_windows_are_replaced() {
        let viewModel = makeViewModel(applications: ["Mail"], windows: [makeWindow("Safari", "GitHub")])
        viewModel.moveSelection(by: 1)

        viewModel.replaceSource(WindowSource(windows: [makeWindow("Safari", "News")]))

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Mail")
    }

    func test_should_keep_selected_window_when_windows_are_replaced() {
        let viewModel = makeViewModel(
            applications: [], windows: [makeWindow("Safari", "GitHub"), makeWindow("Safari", "News")])
        viewModel.moveSelection(by: 1)

        viewModel.replaceSource(
            WindowSource(windows: [makeWindow("Safari", "GitHub"), makeWindow("Safari", "News")]))

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Safari — News")
    }

    func test_should_raise_selected_window() {
        var raisedTitle: String?
        let viewModel = makeViewModel(
            applications: ["Mail"], windows: [makeWindow("Safari", "GitHub")],
            onRaise: { raisedTitle = $0.title })

        viewModel.activateSelectedCandidate()

        XCTAssertEqual(raisedTitle, "GitHub")
    }

    private func makeViewModel(
        applications applicationNames: [String], webSearchEngines: [WebSearchEngine],
        onOpenURL: @escaping (URL) -> Void = { _ in }
    ) -> LauncherViewModel {
        LauncherViewModel(sources: [
            makeApplicationSource(applicationNames),
            WebSearchSource(engines: webSearchEngines, openURL: onOpenURL),
        ])
    }

    func test_should_append_web_searches_after_matching_candidates() {
        let viewModel = makeViewModel(applications: ["Safari"], webSearchEngines: [.google, .googleAIMode])

        viewModel.query = "saf"

        XCTAssertEqual(
            viewModel.candidates.map(\.name), ["Safari", "Search Google: saf", "Ask Google AI Mode: saf"])
    }

    func test_should_list_web_searches_when_nothing_else_matches() {
        let viewModel = makeViewModel(applications: ["Safari"], webSearchEngines: [.google])

        viewModel.query = "zzz"

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Search Google: zzz"])
    }

    func test_should_not_list_web_searches_when_query_is_empty() {
        let viewModel = makeViewModel(applications: ["Safari"], webSearchEngines: [.google])

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Safari"])
    }

    func test_should_not_list_web_searches_when_query_is_only_whitespace() {
        let viewModel = makeViewModel(applications: [], webSearchEngines: [.google])

        viewModel.query = "   "

        XCTAssertEqual(viewModel.candidates.map(\.name), [])
    }

    func test_should_trim_whitespace_from_web_search_query() {
        let viewModel = makeViewModel(applications: [], webSearchEngines: [.google])

        viewModel.query = "  swift  "

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Search Google: swift"])
    }

    func test_should_open_url_of_selected_web_search() {
        var openedURL: URL?
        let viewModel = makeViewModel(
            applications: [], webSearchEngines: [.google], onOpenURL: { openedURL = $0 })
        viewModel.query = "swift"

        viewModel.activateSelectedCandidate()

        XCTAssertEqual(openedURL?.absoluteString, "https://www.google.com/search?q=swift")
    }

    func test_should_report_no_activation_when_web_search_url_is_malformed() {
        let malformedEngine = WebSearchEngine(
            actionLabel: "Search Broken", symbolName: "magnifyingglass",
            baseURL: "http://[invalid", fixedQueryItems: [], queryParameterName: "q")
        let viewModel = makeViewModel(applications: [], webSearchEngines: [malformedEngine])
        viewModel.query = "swift"

        let didActivate = viewModel.activateSelectedCandidate()

        XCTAssertFalse(didActivate)
    }

    func test_should_keep_selected_web_search_when_applications_are_replaced() {
        let viewModel = makeViewModel(applications: [], webSearchEngines: [.google, .googleAIMode])
        viewModel.query = "zzz"
        viewModel.moveSelection(by: 1)

        viewModel.replaceSource(makeApplicationSource(["Mail"]))

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Ask Google AI Mode: zzz")
    }

    private func makeViewModel(
        applications applicationNames: [String], repositories repositoryNames: [String],
        onOpen: @escaping (GhqRepository) -> Void = { _ in }
    ) -> LauncherViewModel {
        LauncherViewModel(sources: [
            makeApplicationSource(applicationNames),
            RepositorySource(repositories: repositoryNames.map(makeRepository), openRepository: onOpen),
        ])
    }

    func test_should_list_repositories_after_applications() {
        let viewModel = makeViewModel(applications: ["Mail"], repositories: ["github.com/a/b"])

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Mail", "github.com/a/b"])
    }

    func test_should_narrow_repositories_by_relative_path() {
        let viewModel = makeViewModel(
            applications: [], repositories: ["github.com/a/emacs", "github.com/a/vim"])

        viewModel.query = "emacs"

        XCTAssertEqual(viewModel.candidates.map(\.name), ["github.com/a/emacs"])
    }

    func test_should_show_replaced_repositories_narrowed_by_current_query() {
        let viewModel = makeViewModel(applications: [], repositories: [])
        viewModel.query = "vim"

        viewModel.replaceSource(
            RepositorySource(repositories: ["github.com/a/emacs", "github.com/a/vim"].map(makeRepository)))

        XCTAssertEqual(viewModel.candidates.map(\.name), ["github.com/a/vim"])
    }

    func test_should_open_selected_repository() {
        var openedName: String?
        let viewModel = makeViewModel(
            applications: [], repositories: ["github.com/a/b"], onOpen: { openedName = $0.name })

        viewModel.activateSelectedCandidate()

        XCTAssertEqual(openedName, "github.com/a/b")
    }

    func test_should_list_web_searches_after_repositories() {
        let viewModel = LauncherViewModel(sources: [
            RepositorySource(repositories: [makeRepository("github.com/a/vim")]),
            WebSearchSource(engines: [.google]),
        ])

        viewModel.query = "vim"

        XCTAssertEqual(viewModel.candidates.map(\.name), ["github.com/a/vim", "Search Google: vim"])
    }

    func test_should_not_treat_same_named_candidates_of_different_sources_as_equal() {
        let applicationCandidate = makeApplicationSource(["vim"]).makeCandidates(matching: "")[0]
        let repositoryCandidate = RepositorySource(repositories: [makeRepository("vim")])
            .makeCandidates(matching: "")[0]

        XCTAssertNotEqual(applicationCandidate, repositoryCandidate)
    }
}
