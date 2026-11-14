import ApplicationServices

/// A window of another running application that the launcher can bring to
/// the front.
struct SwitchableWindow: Hashable {
    let applicationName: String
    let title: String
    let processIdentifier: pid_t
    /// The Accessibility element of the window. Valid only while the window
    /// exists; actions on a closed window fail without side effects.
    let element: AXUIElement

    /// The application name followed by the title, so that the query can
    /// match either.
    var name: String { "\(applicationName) — \(title)" }
}
