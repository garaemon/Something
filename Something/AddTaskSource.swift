import Foundation

/// Lists an "Add task" row for any non-empty query, without narrowing, and
/// captures the query as a task on pick.
struct AddTaskSource: CandidateSource {
    static let addTaskSourceID = CandidateSourceID("addTask")
    let sourceID = AddTaskSource.addTaskSourceID
    let captureTask: (String) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        let title = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return [] }
        let candidate = LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: title),
            name: "Add task: \(title)",
            icon: .systemSymbol("plus.circle"),
            kind: .task,
            actions: [LauncherAction(title: "Add Task", perform: { captureTask(title) })]
        )
        return [candidate]
    }
}
