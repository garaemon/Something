import Foundation

/// A git repository under the repositories folder that the launcher can open.
struct GhqRepository: Hashable {
    /// The path relative to the repositories folder, such as
    /// `github.com/owner/name`.
    let name: String
    let url: URL
}
