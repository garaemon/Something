import Foundation

/// Lists the quicklink whose name starts the query, and opens its URL with
/// the rest of the query filled in. Lists the load error, if any, for every
/// query, so that a broken file is noticed whatever the user types.
struct QuicklinkSource: CandidateSource {
    let sourceID = CandidateSourceID("quicklinks")
    let loadResult: QuicklinkLoadResult
    /// Opens a URL with the application named by the quicklink, or the
    /// default application when nil.
    let openQuicklink: (URL, String?) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        switch loadResult {
        case .failed(let reason):
            return [makeErrorCandidate(reason)]
        case .loaded(let quicklinks):
            let words = query.split(
                maxSplits: 1,
                omittingEmptySubsequences: true,
                whereSeparator: \.isWhitespace
            )
            guard let firstWord = words.first.map(String.init) else { return [] }
            let queryRemainder =
                words.count > 1 ? words[1].trimmingCharacters(in: .whitespaces) : ""
            return quicklinks.compactMap {
                makeCandidate($0, firstWord: firstWord, queryRemainder: queryRemainder)
            }
        }
    }

    private func makeCandidate(
        _ quicklink: Quicklink,
        firstWord: String,
        queryRemainder: String
    ) -> LauncherCandidate? {
        let lowercasedName = quicklink.name.lowercased()
        let nameMatches =
            firstWord.lowercased() == lowercasedName
            || (queryRemainder.isEmpty && lowercasedName.hasPrefix(firstWord.lowercased()))
        guard nameMatches else { return nil }
        let title =
            queryRemainder.isEmpty ? quicklink.name : "\(quicklink.name): \(queryRemainder)"
        // A malformed template still lists the row, but without an action.
        let actions = quicklink.makeURL(query: queryRemainder).map { url in
            let openAction = LauncherAction(
                title: "Open Quicklink",
                perform: { openQuicklink(url, quicklink.application) }
            )
            return [openAction]
        }
        return LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: quicklink),
            name: title,
            icon: .systemSymbol("link"),
            kind: .quicklink,
            actions: actions ?? []
        )
    }

    /// Reads `store` now, so that an edit of the file applies on the next
    /// launcher open, and opens quicklinks through `QuicklinkOpener`.
    static func makeDefault(store: QuicklinkStore) -> QuicklinkSource {
        QuicklinkSource(
            loadResult: store.load(),
            openQuicklink: { QuicklinkOpener.open($0, withApplication: $1) }
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
