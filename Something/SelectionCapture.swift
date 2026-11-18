import Foundation

/// The application that was in front when the launcher opened.
struct SourceApplication: Equatable {
    let processIdentifier: Int32
    let bundleIdentifier: String?
    let name: String
}

/// The frontmost application and its selected text at the moment the launcher
/// opened. Commands such as proofreading or paste back read it later.
struct CapturedSelection: Equatable {
    /// Nil when the frontmost application is unknown or this app itself.
    let sourceApplication: SourceApplication?
    /// Nil when nothing is selected or the selection could not be read.
    let text: String?

    static let empty = CapturedSelection(sourceApplication: nil, text: nil)
}

/// Every representation of every item on the pasteboard, so that a restore
/// keeps rich content such as images and styled text.
struct PasteboardSnapshot: Equatable {
    let items: [[String: Data]]
}

/// The slice of the system pasteboard that the selection capture needs.
protocol SelectionPasteboard {
    var changeCount: Int { get }
    func readSnapshot() -> PasteboardSnapshot
    func readString() -> String?
    /// Replaces the contents with `snapshot`. This bumps `changeCount`.
    func restore(_ snapshot: PasteboardSnapshot)
}

/// Reads the selected text of the frontmost application.
///
/// The Accessibility API comes first. Applications that expose no selection
/// through it, such as some Electron applications, get a synthetic Cmd+C, and
/// the previous pasteboard contents come back afterward.
struct SelectionCapturer {
    let readFrontmostApplication: () -> SourceApplication?
    /// Returns the selected text, an empty string for an empty selection, or
    /// nil when the application does not expose a selection.
    let readAccessibilitySelection: (SourceApplication) -> String?
    let pasteboard: SelectionPasteboard
    /// Posts Cmd+C and returns whether the event was sent.
    let postCopyKey: () -> Bool
    let pauseBetweenPolls: () -> Void
    let maximumPollCount: Int
    let ownProcessIdentifier: Int32

    /// Captures the selection. Runs on the main thread before the launcher
    /// takes the key focus, and blocks for at most the Accessibility timeout
    /// plus `maximumPollCount` pauses.
    func captureSelection() -> CapturedSelection {
        guard let application = readFrontmostApplication(),
            application.processIdentifier != ownProcessIdentifier
        else {
            return .empty
        }
        let accessibilityText = readAccessibilitySelection(application)
        let text = accessibilityText ?? copySelectionThroughPasteboard()
        return CapturedSelection(
            sourceApplication: application,
            text: text?.isEmpty == false ? text : nil
        )
    }

    private func copySelectionThroughPasteboard() -> String? {
        let originalSnapshot = pasteboard.readSnapshot()
        let originalChangeCount = pasteboard.changeCount
        guard postCopyKey() else { return nil }
        for _ in 0..<maximumPollCount {
            pauseBetweenPolls()
            guard pasteboard.changeCount != originalChangeCount else { continue }
            let copiedText = pasteboard.readString()
            pasteboard.restore(originalSnapshot)
            return copiedText
        }
        return nil
    }
}
