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
    private let launchApplication: (LaunchableApplication) -> Void
    private let raiseWindow: (SwitchableWindow) -> Void

    /// Creates a view model that lists `windows` and then `applications`,
    /// all of them while the query is empty.
    init(
        applications: [LaunchableApplication],
        windows: [SwitchableWindow] = [],
        launchApplication: @escaping (LaunchableApplication) -> Void,
        raiseWindow: @escaping (SwitchableWindow) -> Void = { _ in }
    ) {
        self.applications = applications
        self.windows = windows
        self.launchApplication = launchApplication
        self.raiseWindow = raiseWindow
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
        candidates = windowCandidates + applicationCandidates
        selectedIndex = 0
    }
}
