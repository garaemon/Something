import XCTest

@testable import Something

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

        XCTAssertEqual(viewModel.selectedApplication?.name, "Mail")
    }

    func test_should_move_selection_down() {
        let viewModel = makeViewModel(["Safari", "Mail"])

        viewModel.moveSelection(by: 1)

        XCTAssertEqual(viewModel.selectedApplication?.name, "Safari")
    }

    func test_should_stop_at_last_candidate_when_moving_past_the_end() {
        let viewModel = makeViewModel(["Safari", "Mail"])

        viewModel.moveSelection(by: 5)

        XCTAssertEqual(viewModel.selectedApplication?.name, "Safari")
    }

    func test_should_stop_at_first_candidate_when_moving_before_the_start() {
        let viewModel = makeViewModel(["Safari", "Mail"])

        viewModel.moveSelection(by: -10)

        XCTAssertEqual(viewModel.selectedApplication?.name, "Mail")
    }

    func test_should_reset_selection_to_first_when_query_changes() {
        let viewModel = makeViewModel(["Safari", "Mail", "Messages"])
        viewModel.moveSelection(by: 2)

        viewModel.query = "m"

        XCTAssertEqual(viewModel.selectedApplication?.name, "Mail")
    }

    func test_should_have_no_selection_when_nothing_matches() {
        let viewModel = makeViewModel(["Safari"])

        viewModel.query = "zzz"

        XCTAssertNil(viewModel.selectedApplication)
    }

    func test_should_launch_selected_application() {
        var launchedName: String?
        let viewModel = makeViewModel(["Safari", "Mail"]) { launchedName = $0.name }
        viewModel.moveSelection(by: 1)

        viewModel.launchSelectedApplication()

        XCTAssertEqual(launchedName, "Safari")
    }

    func test_should_not_launch_when_nothing_is_selected() {
        var launchCount = 0
        let viewModel = makeViewModel(["Safari"]) { _ in launchCount += 1 }
        viewModel.query = "zzz"

        viewModel.launchSelectedApplication()

        XCTAssertEqual(launchCount, 0)
    }
}
