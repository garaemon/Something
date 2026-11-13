import Foundation

/// An application bundle that the launcher can open.
struct LaunchableApplication: Hashable, Identifiable {
    /// The bundle file name without the `.app` extension, as Finder shows it.
    let name: String
    let url: URL

    var id: URL { url }
}
