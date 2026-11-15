import Foundation

/// Lists the files under the file folders for a non-empty query, narrowed by
/// their paths, and opens the picked one.
struct FileSource: CandidateSource {
    /// The most rows that one query lists. The folders can hold thousands of
    /// files, which would push the web searches far below the visible rows.
    static let candidateLimit = 50

    let sourceID = CandidateSourceID("files")
    /// Most recently modified first, an order that the narrowed rows keep.
    let files: [LocalFile]
    let openFile: (LocalFile) -> Void
    let revealFile: (LocalFile) -> Void

    // An empty query lists nothing, so that opening the launcher does not
    // bury the repositories under every file of the folders.
    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        let patterns = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !patterns.isEmpty else { return [] }
        let matchedFiles = files.lazy.filter { file in
            let lowercasedName = file.name.lowercased()
            return patterns.allSatisfy { lowercasedName.contains($0) }
        }
        return matchedFiles.prefix(Self.candidateLimit).map(makeCandidate)
    }

    private func makeCandidate(for file: LocalFile) -> LauncherCandidate {
        LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: file),
            name: file.name, icon: .fileType(extension: file.url.pathExtension.lowercased()), kind: .file,
            actions: [
                LauncherAction(title: "Open") { openFile(file) },
                LauncherAction(title: "Reveal in Finder") { revealFile(file) },
            ])
    }
}
