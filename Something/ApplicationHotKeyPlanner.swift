import Foundation

/// An application that a hot key opens.
struct ApplicationTarget: Codable, Equatable, Hashable {
    /// File path of the `.app` bundle.
    let path: String
    /// Finds the running instance when the bundle moved. Nil for a bundle
    /// without an identifier.
    let bundleIdentifier: String?

    var url: URL { URL(fileURLWithPath: path) }

    /// The bundle file name without `.app`, as the application list shows it.
    var name: String { url.deletingPathExtension().lastPathComponent }
}

/// What a hot key press does to its application.
enum ApplicationHotKeyAction: Equatable {
    case launch
    case activate
    /// Raises the window at this index of the frontmost-first window list.
    case raiseWindow(index: Int)
}

/// Decides what an application hot key does. Pure, so that the decision is
/// testable without a running application.
enum ApplicationHotKeyPlanner {
    /// Launches a closed application, activates a background one, and, for a
    /// frontmost one with several windows, raises the rearmost window.
    ///
    /// The Accessibility API lists windows front to back. Raising the rearmost
    /// window on each press therefore walks through every window in turn.
    static func plan(
        isRunning: Bool,
        isFrontmost: Bool,
        windowCount: Int
    ) -> ApplicationHotKeyAction {
        guard isRunning else { return .launch }
        guard isFrontmost, windowCount > 1 else { return .activate }
        return .raiseWindow(index: windowCount - 1)
    }
}
