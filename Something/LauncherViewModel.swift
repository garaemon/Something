import Foundation

/// Holds the launcher's query, the narrowed candidates, and the selection.
/// The launcher can also list the actions of one candidate in place of the
/// candidates, with its own query and selection.
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

    /// The query that narrows the action list. Empty each time the list opens.
    @Published var actionQuery = "" {
        didSet {
            guard actionQuery != oldValue else { return }
            updateActions()
        }
    }
    /// The candidate whose actions the launcher lists, or nil while it lists
    /// candidates.
    @Published private(set) var actionTarget: LauncherCandidate?
    @Published private(set) var actions: [LauncherAction] = []
    @Published private(set) var selectedActionIndex = 0

    private var sources: [any CandidateSource]

    /// Creates a view model that lists the candidates of `sources`, one source
    /// after another in the given order.
    init(sources: [any CandidateSource]) {
        self.sources = sources
        updateCandidates()
    }

    /// The highlighted candidate, or nil when no candidate matches the query.
    var selectedCandidate: LauncherCandidate? {
        candidates.indices.contains(selectedIndex) ? candidates[selectedIndex] : nil
    }

    var isShowingActions: Bool { actionTarget != nil }

    /// The highlighted action, or nil when the action list is closed or empty.
    var selectedAction: LauncherAction? {
        actions.indices.contains(selectedActionIndex) ? actions[selectedActionIndex] : nil
    }

    /// Lists the actions of the selected candidate in place of the candidates.
    ///
    /// - Returns: Whether the action list is open now. False when no candidate
    ///   is selected or the candidate has no action.
    @discardableResult
    func showActions() -> Bool {
        if isShowingActions { return true }
        guard let candidate = selectedCandidate, !candidate.actions.isEmpty else { return false }
        actionTarget = candidate
        actionQuery = ""
        updateActions()
        return true
    }

    /// Highlights the action at `index` of the action list. Ignores an index
    /// outside the list.
    func selectAction(at index: Int) {
        guard actions.indices.contains(index) else { return }
        selectedActionIndex = index
    }

    /// Goes back from the action list to the candidates, which keep their
    /// query and highlight.
    ///
    /// - Returns: Whether the action list was open.
    @discardableResult
    func hideActions() -> Bool {
        guard isShowingActions else { return false }
        actionTarget = nil
        actionQuery = ""
        actions = []
        return true
    }

    /// Moves the highlight by `offset` rows, stopping at the first and last
    /// rows. Moves in the action list while it is open.
    func moveSelection(by offset: Int) {
        if isShowingActions {
            guard !actions.isEmpty else { return }
            selectedActionIndex = min(max(selectedActionIndex + offset, 0), actions.count - 1)
            return
        }
        guard !candidates.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), candidates.count - 1)
    }

    /// Highlights `candidate`. Keeps the current highlight when `candidate`
    /// is not among the candidates.
    func selectCandidate(_ candidate: LauncherCandidate) {
        guard let index = candidates.firstIndex(of: candidate) else { return }
        selectedIndex = index
    }

    /// Swaps in `newSource` for the source with the same identifier, such as
    /// the result of a rescan, keeping the query and the highlighted candidate
    /// when it still matches. Ignores a source that the launcher does not list.
    func replaceSource(_ newSource: any CandidateSource) {
        guard let index = sources.firstIndex(where: { $0.sourceID == newSource.sourceID }) else {
            return
        }
        let previouslySelectedCandidate = selectedCandidate
        sources[index] = newSource
        updateCandidates()
        selectedIndex = candidates.firstIndex { $0 == previouslySelectedCandidate } ?? 0
    }

    /// Runs the default action of the selected candidate synchronously, or
    /// the highlighted action while the action list is open.
    /// Does nothing when no candidate or action matches the query or the
    /// selected candidate has no action.
    ///
    /// - Returns: Whether an action ran.
    @discardableResult
    func activateSelection() -> Bool {
        let action = isShowingActions ? selectedAction : selectedCandidate?.defaultAction
        guard let action else { return false }
        action.perform()
        return true
    }

    // Keeps the order of the actions, unlike the candidate matcher, so that
    // the default action stays first.
    private func updateActions() {
        let patterns = ApplicationMatcher.splitPatterns(actionQuery)
        actions = (actionTarget?.actions ?? []).filter {
            ApplicationMatcher.containsAllPatterns($0.title.lowercased(), patterns: patterns)
        }
        selectedActionIndex = 0
    }

    private func updateCandidates() {
        candidates = sources.flatMap { $0.makeCandidates(matching: query) }
        selectedIndex = 0
    }
}
