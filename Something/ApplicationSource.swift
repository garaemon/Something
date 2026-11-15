import Foundation

/// Lists application bundles, narrowed by name, and launches the picked one.
struct ApplicationSource: CandidateSource {
    let sourceID = CandidateSourceID("applications")
    let applications: [LaunchableApplication]
    let launchApplication: (LaunchableApplication) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        ApplicationMatcher.filterApplications(applications, matching: query).map(makeCandidate)
    }

    private func makeCandidate(for application: LaunchableApplication) -> LauncherCandidate {
        LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: application),
            name: application.name,
            icon: .applicationBundle(application),
            kind: .application,
            actions: [LauncherAction(title: "Open") { launchApplication(application) }]
        )
    }
}
