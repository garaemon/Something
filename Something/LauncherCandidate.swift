import Foundation

/// One row of the launcher: something that the user can narrow and pick.
enum LauncherCandidate: Hashable, Identifiable {
    case application(LaunchableApplication)
    case window(SwitchableWindow)
    case repository(GhqRepository)
    case webSearch(WebSearch)

    /// The text that the row shows. The query narrows applications, windows,
    /// and repositories by this text, but not web searches.
    var name: String {
        switch self {
        case .application(let application):
            return application.name
        case .window(let window):
            return window.name
        case .repository(let repository):
            return repository.name
        case .webSearch(let search):
            return search.title
        }
    }

    var id: Self { self }
}
