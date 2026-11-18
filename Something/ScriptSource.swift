import Foundation

/// Lists the rows that Python sources added with `something.add_source`, narrowed by title,
/// and runs the Python action of the picked one.
///
/// All Python sources share this one source, so that the launcher swaps them as a whole when
/// a collection finishes.
struct ScriptSource: CandidateSource {
    let sourceID = CandidateSourceID("scripts")
    let items: [ScriptItem]
    /// Runs the action with the given generation and index. The caller decides on which
    /// thread, so that this source stays free of the interpreter.
    let runAction: (_ generation: Int, _ index: Int) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        let identified = identify(items)
        return ApplicationMatcher.filterItems(identified, matching: query, name: \.item.title)
            .map(makeCandidate)
    }

    private struct IdentifiedItem {
        let item: ScriptItem
        let identity: Identity
    }

    // The generation is left out, because it changes on every collection and would drop the
    // highlight of the row on each refresh. The occurrence number tells apart rows of one
    // source that share a title.
    private struct Identity: Hashable {
        let source: String
        let title: String
        let occurrence: Int
    }

    private func identify(_ items: [ScriptItem]) -> [IdentifiedItem] {
        var occurrenceCounts: [[String]: Int] = [:]
        return items.map { item in
            let key = [item.source, item.title]
            let occurrence = occurrenceCounts[key, default: 0]
            occurrenceCounts[key] = occurrence + 1
            return IdentifiedItem(
                item: item,
                identity: Identity(source: item.source, title: item.title, occurrence: occurrence)
            )
        }
    }

    private func makeCandidate(for identified: IdentifiedItem) -> LauncherCandidate {
        let item = identified.item
        var actions: [LauncherAction] = []
        if let index = item.action {
            actions = [LauncherAction(title: "Run", perform: { runAction(item.generation, index) })]
        }
        return LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: identified.identity),
            name: item.title,
            icon: .systemSymbol(LauncherCandidateKind.script.symbolName),
            kind: .script,
            actions: actions
        )
    }
}
