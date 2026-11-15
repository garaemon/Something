import Foundation

/// Lists git repositories, narrowed by their path relative to the repositories
/// folder, and opens the picked one.
struct RepositorySource: CandidateSource {
    let sourceID = CandidateSourceID("repositories")
    let repositories: [GhqRepository]
    let openRepository: (GhqRepository) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        ApplicationMatcher.filterItems(repositories, matching: query, name: \.name).map(makeCandidate)
    }

    private func makeCandidate(for repository: GhqRepository) -> LauncherCandidate {
        LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: repository),
            name: repository.name, icon: .folder,
            actions: [LauncherAction(title: "Open in Finder") { openRepository(repository) }])
    }
}
