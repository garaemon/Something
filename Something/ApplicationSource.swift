import Foundation

/// Lists application bundles, narrowed by name, and launches the picked one.
struct ApplicationSource: CandidateSource {
    let sourceID = CandidateSourceID("applications")
    let applications: [LaunchableApplication]
    let launchApplication: (LaunchableApplication) -> Void

    init(
        applications: [LaunchableApplication],
        launchApplication: @escaping (LaunchableApplication) -> Void = { _ in }
    ) {
        self.applications = applications
        self.launchApplication = launchApplication
    }

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        ApplicationMatcher.filterApplications(applications, matching: query).map(makeCandidate)
    }

    private func makeCandidate(for application: LaunchableApplication) -> LauncherCandidate {
        let launch = launchApplication
        return LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: application),
            name: application.name, icon: .applicationBundle(application),
            actions: [LauncherAction(title: "Open") { launch(application) }])
    }
}
