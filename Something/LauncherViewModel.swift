import Foundation

/// Holds the launcher's query, the narrowed candidates, and the selection.
@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var query = "" {
        didSet {
            // SwiftUI's TextField writes the unchanged text back, for example
            // on Return, and rebuilding the candidates resets the highlight.
            guard query != oldValue else { return }
            updateCandidates()
        }
    }
    @Published private(set) var candidates: [LauncherCandidate] = []
    @Published private(set) var selectedIndex = 0

    private var applications: [LaunchableApplication]
    private var windows: [SwitchableWindow]
    private var repositories: [GhqRepository]
    private let launchApplication: (LaunchableApplication) -> Void
    private let raiseWindow: (SwitchableWindow) -> Void
    private let openRepository: (GhqRepository) -> Void
    private let webSearchEngines: [WebSearchEngine]
    private let openURL: (URL) -> Void

    /// Creates a view model that lists `windows`, `applications`, and then
    /// `repositories`, all of them while the query is empty. A non-empty query
    /// also lists one search per engine in `webSearchEngines` at the end.
    init(
        applications: [LaunchableApplication],
        windows: [SwitchableWindow] = [],
        repositories: [GhqRepository] = [],
        launchApplication: @escaping (LaunchableApplication) -> Void,
        raiseWindow: @escaping (SwitchableWindow) -> Void = { _ in },
        openRepository: @escaping (GhqRepository) -> Void = { _ in },
        webSearchEngines: [WebSearchEngine] = [],
        openURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.applications = applications
        self.windows = windows
        self.repositories = repositories
        self.launchApplication = launchApplication
        self.raiseWindow = raiseWindow
        self.openRepository = openRepository
        self.webSearchEngines = webSearchEngines
        self.openURL = openURL
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
        updateCandidatesKeepingSelection { applications = newApplications }
    }

    /// Swaps in a new set of windows, such as a fresh window list, keeping the
    /// query and the highlighted candidate when it still matches.
    func replaceWindows(_ newWindows: [SwitchableWindow]) {
        updateCandidatesKeepingSelection { windows = newWindows }
    }

    /// Swaps in a new set of repositories, such as a fresh scan, keeping
    /// the query and the highlighted candidate when it still matches.
    func replaceRepositories(_ newRepositories: [GhqRepository]) {
        updateCandidatesKeepingSelection { repositories = newRepositories }
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
        case .window(let window):
            raiseWindow(window)
        case .repository(let repository):
            openRepository(repository)
        case .webSearch(let search):
            guard let url = search.url else { return false }
            openURL(url)
        }
        return true
    }

    private func updateCandidatesKeepingSelection(afterReplacing replaceSource: () -> Void) {
        let previouslySelectedCandidate = selectedCandidate
        replaceSource()
        updateCandidates()
        selectedIndex = candidates.firstIndex { $0 == previouslySelectedCandidate } ?? 0
    }

    private func updateCandidates() {
        let windowCandidates = ApplicationMatcher.filterItems(windows, matching: query, name: \.name)
            .map(LauncherCandidate.window)
        let applicationCandidates = ApplicationMatcher.filterApplications(applications, matching: query)
            .map(LauncherCandidate.application)
        let repositoryCandidates = ApplicationMatcher.filterItems(repositories, matching: query, name: \.name)
            .map(LauncherCandidate.repository)
        candidates =
            windowCandidates + applicationCandidates + repositoryCandidates + makeWebSearchCandidates()
        selectedIndex = 0
    }

    private func makeWebSearchCandidates() -> [LauncherCandidate] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        return webSearchEngines.map { .webSearch(WebSearch(engine: $0, query: trimmedQuery)) }
    }
}
