import Foundation

/// Lists one search per engine for any non-empty query, without narrowing,
/// and opens the picked search in the browser.
struct WebSearchSource: CandidateSource {
    static let sourceID = CandidateSourceID("webSearches")

    let engines: [WebSearchEngine]
    let openURL: (URL) -> Void

    init(engines: [WebSearchEngine], openURL: @escaping (URL) -> Void = { _ in }) {
        self.engines = engines
        self.openURL = openURL
    }

    var sourceID: CandidateSourceID { Self.sourceID }

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        return engines.map { makeCandidate(for: WebSearch(engine: $0, query: trimmedQuery)) }
    }

    // A malformed engine URL still lists the row, but without an action, so
    // Return keeps the launcher open instead of closing it for nothing.
    private func makeCandidate(for search: WebSearch) -> LauncherCandidate {
        let open = openURL
        let actions = search.url.map { url in [LauncherAction(title: "Open in Browser") { open(url) }] }
        return LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: search),
            name: search.title, icon: .systemSymbol(search.engine.symbolName),
            actions: actions ?? [])
    }
}
