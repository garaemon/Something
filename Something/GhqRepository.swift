import Foundation

/// A repository under a ghq root that the launcher can open.
struct GhqRepository: Hashable {
    /// The path relative to its ghq root, such as `github.com/owner/name`.
    let name: String
    let url: URL
}
