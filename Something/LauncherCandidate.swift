import Foundation

/// One row of the launcher: something that the user can narrow and pick.
enum LauncherCandidate: Hashable, Identifiable {
    case application(LaunchableApplication)

    /// The text that the query narrows and that the row shows.
    var name: String {
        switch self {
        case .application(let application):
            return application.name
        }
    }

    var id: Self { self }
}
