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

    /// Runs the default action of the selected candidate synchronously.
    /// Does nothing when no candidate matches the query or the selected
    /// candidate has no action.
    ///
    /// - Returns: Whether an action ran.
    @discardableResult
    func activateSelectedCandidate() -> Bool {
        guard let action = selectedCandidate?.defaultAction else { return false }
        action.perform()
        return true
    }

    /// Runs the "Add task" row for the current query, whichever row is
    /// highlighted. Does nothing for an empty query.
    ///
    /// - Returns: Whether a task was captured.
    @discardableResult
    func activateTaskCapture() -> Bool {
        let addTaskCandidate = candidates.first {
            $0.id.sourceID == AddTaskSource.addTaskSourceID
        }
        guard let action = addTaskCandidate?.defaultAction else { return false }
        action.perform()
        return true
    }

    private func updateCandidates() {
        candidates = sources.flatMap { $0.makeCandidates(matching: query) }
        selectedIndex = 0
    }
}
