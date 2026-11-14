import Foundation

/// Holds the launcher's query, the narrowed candidates, and the selection.
@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var query = "" {
        didSet { updateCandidates() }
    }
    @Published private(set) var candidates: [LauncherCandidate] = []
    @Published private(set) var selectedIndex = 0

    private var applications: [LaunchableApplication]
    private let launchApplication: (LaunchableApplication) -> Void

    /// Creates a view model that lists `applications`, all of them while the
    /// query is empty.
    init(
        applications: [LaunchableApplication],
        launchApplication: @escaping (LaunchableApplication) -> Void
    ) {
        self.applications = applications
        self.launchApplication = launchApplication
        updateCandidates()
    }

    /// The highlighted candidate, or nil when no candidate matches the query.
    var selectedCandidate: LauncherCandidate? {
        candidates.indices.contains(selectedIndex) ? candidates[selectedIndex] : nil
    }

    /// Moves the highlight by `offset` rows, stopping at the first and last rows.
    func moveSelection(by offset: Int) {
        guard !candidates.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), candidates.count - 1)
    }

    /// Highlights `candidate`. Keeps the current highlight when `candidate`
    /// is not among the candidates.
    func selectCandidate(_ candidate: LauncherCandidate) {
        guard let index = candidates.firstIndex(of: candidate) else { return }
        selectedIndex = index
    }

    /// Swaps in a new set of applications, such as the result of a rescan,
    /// keeping the query and the highlighted candidate when it still matches.
    func replaceApplications(_ newApplications: [LaunchableApplication]) {
        let previouslySelectedCandidate = selectedCandidate
        applications = newApplications
        updateCandidates()
        selectedIndex = candidates.firstIndex { $0 == previouslySelectedCandidate } ?? 0
    }

    /// Hands the selected candidate synchronously to the matching closure.
    /// Does nothing when no candidate matches the query.
    ///
    /// - Returns: Whether a candidate was selected and handed to a closure.
    @discardableResult
    func activateSelectedCandidate() -> Bool {
        guard let candidate = selectedCandidate else { return false }
        switch candidate {
        case .application(let application):
            launchApplication(application)
        }
        return true
    }

    private func updateCandidates() {
        candidates = ApplicationMatcher.filterApplications(applications, matching: query)
            .map(LauncherCandidate.application)
        selectedIndex = 0
    }
}
