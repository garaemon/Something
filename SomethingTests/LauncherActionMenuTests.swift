import XCTest

@testable import Something

@MainActor
final class LauncherActionMenuTests: XCTestCase {
    private struct ActionSource: CandidateSource {
        let sourceID = CandidateSourceID("test-actions")
        let actionTitles: [String]
        let performed: (String) -> Void

        func makeCandidates(matching query: String) -> [LauncherCandidate] {
            [
                LauncherCandidate(
                    id: LauncherCandidateID(sourceID: sourceID, item: "row"),
                    name: "row",
                    icon: .folder,
                    kind: .file,
                    actions: actionTitles.map { title in
                        LauncherAction(title: title, perform: { performed(title) })
                    }
                )
            ]
        }
    }

    private func makeViewModel(
        titles: [String] = ["Open", "Reveal in Finder", "Copy Path"],
        performed: @escaping (String) -> Void = { _ in }
    ) -> LauncherViewModel {
        LauncherViewModel(sources: [ActionSource(actionTitles: titles, performed: performed)])
    }

    func test_should_list_all_actions_when_showing_actions() {
        let viewModel = makeViewModel()

        viewModel.showActions()

        XCTAssertEqual(viewModel.actions.map(\.title), ["Open", "Reveal in Finder", "Copy Path"])
    }

    func test_should_be_in_action_mode_after_showing_actions() {
        let viewModel = makeViewModel()

        viewModel.showActions()

        XCTAssertTrue(viewModel.isShowingActions)
    }

    func test_should_not_show_actions_when_candidate_has_none() {
        let viewModel = makeViewModel(titles: [])

        let didShow = viewModel.showActions()

        XCTAssertFalse(didShow)
        XCTAssertFalse(viewModel.isShowingActions)
    }

    func test_should_narrow_actions_by_action_query() {
        let viewModel = makeViewModel()
        viewModel.showActions()

        viewModel.actionQuery = "reveal"

        XCTAssertEqual(viewModel.actions.map(\.title), ["Reveal in Finder"])
    }

    func test_should_keep_action_order_when_narrowing() {
        let viewModel = makeViewModel()
        viewModel.showActions()

        viewModel.actionQuery = "p"

        XCTAssertEqual(viewModel.actions.map(\.title), ["Open", "Copy Path"])
    }

    func test_should_highlight_first_action_initially() {
        let viewModel = makeViewModel()

        viewModel.showActions()

        XCTAssertEqual(viewModel.selectedAction?.title, "Open")
    }

    func test_should_move_action_selection_and_clamp() {
        let viewModel = makeViewModel()
        viewModel.showActions()

        viewModel.moveSelection(by: 5)

        XCTAssertEqual(viewModel.selectedAction?.title, "Copy Path")
    }

    func test_should_not_move_candidate_selection_in_action_mode() {
        let viewModel = makeViewModel()
        viewModel.showActions()

        viewModel.moveSelection(by: 1)

        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func test_should_run_highlighted_action_on_activate() {
        var performedTitles: [String] = []
        let viewModel = makeViewModel(performed: { performedTitles.append($0) })
        viewModel.showActions()
        viewModel.moveSelection(by: 1)

        let didActivate = viewModel.activateSelectedCandidate()

        XCTAssertTrue(didActivate)
        XCTAssertEqual(performedTitles, ["Reveal in Finder"])
    }

    func test_should_not_activate_when_no_action_matches() {
        var performedTitles: [String] = []
        let viewModel = makeViewModel(performed: { performedTitles.append($0) })
        viewModel.showActions()

        viewModel.actionQuery = "zzz"

        XCTAssertFalse(viewModel.activateSelectedCandidate())
        XCTAssertTrue(performedTitles.isEmpty)
    }

    func test_should_return_to_candidates_when_hiding_actions() {
        let viewModel = makeViewModel()
        viewModel.query = "ro"
        viewModel.showActions()

        let didHide = viewModel.hideActions()

        XCTAssertTrue(didHide)
        XCTAssertFalse(viewModel.isShowingActions)
        XCTAssertEqual(viewModel.query, "ro")
    }

    func test_should_report_nothing_to_hide_outside_action_mode() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.hideActions())
    }

    func test_should_clear_action_query_when_showing_actions_again() {
        let viewModel = makeViewModel()
        viewModel.showActions()
        viewModel.actionQuery = "copy"
        viewModel.hideActions()

        viewModel.showActions()

        XCTAssertEqual(viewModel.actionQuery, "")
        XCTAssertEqual(viewModel.actions.count, 3)
    }
}
