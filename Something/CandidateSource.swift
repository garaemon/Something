import Foundation

/// Produces the launcher candidates of one kind, such as applications, for a
/// query. Adding a kind of candidate means adding a source.
protocol CandidateSource {
    /// Tells this source apart from the other sources of a launcher. A source
    /// with the same identifier replaces this one on a rescan.
    var sourceID: CandidateSourceID { get }

    /// Returns the candidates that `query` selects, in display order.
    func makeCandidates(matching query: String) -> [LauncherCandidate]
}

/// The name of one candidate source, such as `applications`.
struct CandidateSourceID: Hashable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
