import Foundation

/// One row of the launcher: something that the user can narrow and pick.
///
/// Two candidates are equal when their identifiers are equal, so that a
/// rebuilt candidate with fresh action closures still keeps the highlight.
struct LauncherCandidate: Hashable, Identifiable {
    let id: LauncherCandidateID
    /// The text that the row shows.
    let name: String
    let icon: LauncherCandidateIcon
    let kind: LauncherCandidateKind
    /// The things the user can do with the candidate. The first action runs
    /// on Return; an empty list makes the candidate impossible to pick.
    let actions: [LauncherAction]

    var defaultAction: LauncherAction? { actions.first }

    static func == (lhs: LauncherCandidate, rhs: LauncherCandidate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Identifies a candidate across rebuilds. The source keeps an item of one
/// source from colliding with an equal item of another source.
struct LauncherCandidateID: Hashable {
    let sourceID: CandidateSourceID
    let item: AnyHashable
}

/// The picture that a launcher row shows. The view resolves the picture to an
/// image, so that sources stay free of AppKit.
enum LauncherCandidateIcon: Hashable {
    case applicationBundle(LaunchableApplication)
    case runningApplication(pid_t)
    case folder
    /// The icon of a file type, such as "pdf". An empty extension stands for
    /// a generic document.
    case fileType(extension: String)
    case systemSymbol(String)
}

/// The kind of thing that a row stands for, shown beside its name so that the
/// user can tell a window of Safari from the Safari application.
enum LauncherCandidateKind: CaseIterable {
    case window
    case application
    case repository
    case file
    case quicklink
    case webSearch
    case settings
    case calculator
    case unit
    case scratch
    case capture
    case task

    /// The short text of the badge, such as "Window".
    var label: String {
        switch self {
        case .window: "Window"
        case .application: "App"
        case .repository: "Repo"
        case .file: "File"
        case .quicklink: "Link"
        case .webSearch: "Web"
        case .settings: "Settings"
        case .calculator: "Calc"
        case .unit: "Unit"
        case .scratch: "Scratch"
        case .capture: "Capture"
        case .task: "Task"
        }
    }

    /// The SF Symbol name of the badge. The settings badge avoids gearshape,
    /// because the settings row already shows gearshape as its icon.
    var symbolName: String {
        switch self {
        case .window: "macwindow"
        case .application: "app.badge"
        case .repository: "arrow.triangle.branch"
        case .file: "doc"
        case .quicklink: "link"
        case .webSearch: "globe"
        case .settings: "slider.horizontal.3"
        case .calculator: "function"
        case .unit: "ruler"
        case .scratch: "text.cursor"
        case .capture: "camera.viewfinder"
        case .task: "checklist"
        }
    }
}

/// One thing that the user can do with a candidate, such as opening it.
struct LauncherAction {
    /// The label of the action, such as "Open in Finder".
    let title: String
    let perform: () -> Void
}
