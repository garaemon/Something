import Foundation

/// Lists the quicklink whose name starts the query, and opens its URL with
/// the rest of the query filled in. Lists the load error, if any, while the
/// query is empty.
struct QuicklinkSource: CandidateSource {
    let sourceID = CandidateSourceID("quicklinks")
    let loadResult: QuicklinkLoadResult
    /// Opens a URL with the application named by the quicklink, or the
    /// default application when nil.
    let openQuicklink: (URL, String?) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        switch loadResult {
        case .failed(let reason):
            return query.trimmingCharacters(in: .whitespaces).isEmpty
                ? [makeErrorCandidate(reason)] : []
        case .loaded(let quicklinks):
            return quicklinks.compactMap { makeCandidate($0, query: query) }
        }
    }

    private func makeCandidate(_ quicklink: Quicklink, query: String) -> LauncherCandidate? {
        let words = query.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: \.isWhitespace
        )
        guard let firstWord = words.first else { return nil }
        let rest = words.count > 1 ? words[1].trimmingCharacters(in: .whitespaces) : ""
        let lowercasedName = quicklink.name.lowercased()
        let nameMatches =
            firstWord.lowercased() == lowercasedName
            || (rest.isEmpty && lowercasedName.hasPrefix(firstWord.lowercased()))
        guard nameMatches else { return nil }
        let title = rest.isEmpty ? quicklink.name : "\(quicklink.name): \(rest)"
        // A malformed template still lists the row, but without an action.
        let actions = quicklink.makeURL(query: rest).map { url in
            let open = LauncherAction(
                title: "Open Quicklink",
                perform: { openQuicklink(url, quicklink.application) }
            )
            return [open]
        }
        return LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: quicklink),
            name: title,
            icon: .systemSymbol("link"),
            kind: .quicklink,
            actions: actions ?? []
        )
    }

    private func makeErrorCandidate(_ reason: String) -> LauncherCandidate {
        LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: "error"),
            name: "Cannot read quicklinks.json: \(reason)",
            icon: .systemSymbol("exclamationmark.triangle"),
            kind: .quicklink,
            actions: []
        )
    }
}
