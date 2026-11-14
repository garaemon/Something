import XCTest

@testable import Something

@MainActor
final class LauncherViewModelTests: XCTestCase {
    private func makeViewModel(
        _ names: [String], onLaunch: @escaping (LaunchableApplication) -> Void = { _ in }
    ) -> LauncherViewModel {
        LauncherViewModel(applications: names.map(makeApplication), launchApplication: onLaunch)
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

        viewModel.replaceApplications(["Safari", "Mail"].map(makeApplication))

        XCTAssertEqual(viewModel.candidates.map(\.name), ["Safari"])
    }

    func test_should_keep_selected_candidate_when_applications_are_replaced() {
        let viewModel = makeViewModel(["Mail", "Safari"])
        viewModel.moveSelection(by: 1)

        viewModel.replaceApplications(["Calendar", "Mail", "Safari"].map(makeApplication))

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Safari")
    }

    func test_should_select_first_candidate_when_selected_candidate_disappears() {
        let viewModel = makeViewModel(["Mail", "Safari"])
        viewModel.moveSelection(by: 1)

        viewModel.replaceApplications(["Calendar", "Mail"].map(makeApplication))

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Calendar")
    }

    func test_should_keep_selection_index_when_moving_without_candidates() {
        let viewModel = makeViewModel(["Safari"])
        viewModel.query = "zzz"

        viewModel.moveSelection(by: 1)

        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func test_should_report_launch_when_a_candidate_is_selected() {
        let viewModel = makeViewModel(["Safari"])

        let didLaunch = viewModel.activateSelectedCandidate()

        XCTAssertTrue(didLaunch)
    }

    func test_should_report_no_launch_when_nothing_is_selected() {
        let viewModel = makeViewModel(["Safari"])
        viewModel.query = "zzz"

        let didLaunch = viewModel.activateSelectedCandidate()

        XCTAssertFalse(didLaunch)
    }

    func test_should_select_clicked_candidate() {
        let viewModel = makeViewModel(["Mail", "Safari"])

        viewModel.selectCandidate(.application(makeApplication("Safari")))

        XCTAssertEqual(viewModel.selectedCandidate?.name, "Safari")
    }

    func test_should_keep_selection_when_selecting_candidate_not_in_candidates() {
        let viewModel = makeViewModel(["Mail", "Safari"])

        viewModel.selectCandidate(.application(makeApplication("Calendar")))

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
}
