import Foundation

/// Lists one row that opens the Python scratch buffer when the query matches
/// "Python Scratch".
struct ScratchSource: CandidateSource {
    static let candidateName = "Python Scratch"

    let sourceID = CandidateSourceID("scratch")
    let openScratch: () -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
            !ApplicationMatcher.filterItems([Self.candidateName], matching: query, name: { $0 })
                .isEmpty
        else { return [] }
        let scratchCandidate = LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: Self.candidateName),
            name: Self.candidateName,
            icon: .systemSymbol("chevron.left.forwardslash.chevron.right"),
            kind: .scratch,
            actions: [LauncherAction(title: "Open Scratch", perform: openScratch)]
        )
        return [scratchCandidate]
    }
}
