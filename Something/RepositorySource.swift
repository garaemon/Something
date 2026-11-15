import Foundation

/// Lists ghq repositories, narrowed by their path relative to the ghq root,
/// and opens the picked one.
struct RepositorySource: CandidateSource {
    static let sourceID = CandidateSourceID("repositories")

    let repositories: [GhqRepository]
    let openRepository: (GhqRepository) -> Void

    init(repositories: [GhqRepository], openRepository: @escaping (GhqRepository) -> Void = { _ in }) {
        self.repositories = repositories
        self.openRepository = openRepository
    }

    var sourceID: CandidateSourceID { Self.sourceID }

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        ApplicationMatcher.filterItems(repositories, matching: query, name: \.name).map(makeCandidate)
    }

    private func makeCandidate(for repository: GhqRepository) -> LauncherCandidate {
        let open = openRepository
        return LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: repository),
            name: repository.name, icon: .folder,
            actions: [LauncherAction(title: "Open in Finder") { open(repository) }])
    }
}
