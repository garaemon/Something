import Foundation

/// An application bundle that the launcher can open.
struct LaunchableApplication: Hashable, Identifiable {
    /// The bundle file name without the `.app` extension. This is not the
    /// localized name that Finder may show, such as a Japanese name.
    let name: String
    let url: URL

    var id: URL { url }
}
