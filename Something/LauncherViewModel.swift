import Foundation

/// Holds the launcher's query, the narrowed candidates, and the selection.
@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var query = "" {
        didSet { updateCandidates() }
    }
    @Published private(set) var candidates: [LaunchableApplication] = []
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
    var selectedApplication: LaunchableApplication? {
        candidates.indices.contains(selectedIndex) ? candidates[selectedIndex] : nil
    }

    /// Moves the highlight by `offset` rows, stopping at the first and last rows.
    func moveSelection(by offset: Int) {
        guard !candidates.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), candidates.count - 1)
    }

    /// Swaps in a new set of applications, such as the result of a rescan,
    /// keeping the query and the highlighted application when it still matches.
    func replaceApplications(_ newApplications: [LaunchableApplication]) {
        let previouslySelectedID = selectedApplication?.id
        applications = newApplications
        updateCandidates()
        selectedIndex = candidates.firstIndex { $0.id == previouslySelectedID } ?? 0
    }

    /// Calls the `launchApplication` closure synchronously with the selected
    /// candidate. Does nothing when no candidate matches the query.
    func launchSelectedApplication() {
        guard let application = selectedApplication else { return }
        launchApplication(application)
    }

    private func updateCandidates() {
        candidates = ApplicationMatcher.filterApplications(applications, matching: query)
        selectedIndex = 0
    }
}
