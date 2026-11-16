import AppKit

/// Builds the subtitle of the scratch window from the run status and the last save failure,
/// so that one of them never erases the other.
@MainActor
final class ScratchSubtitle {
    /// The text while Python runs. A run blocked in C, such as `time.sleep`, can last past
    /// the watchdog, and the read-only text would otherwise look frozen.
    static let runningText = "Running…"
    static let droppedResultsText = "Results dropped: the text changed during the run"

    private weak var window: NSWindow?

    var runStatus = ScratchRunStatus.idle {
        didSet { updateWindow() }
    }
    /// The description of the error of the last save, or nil when it succeeded.
    var saveFailure: String? {
        didSet { updateWindow() }
    }

    init(window: NSWindow) {
        self.window = window
    }

    private func updateWindow() {
        let runText: String? =
            switch runStatus {
            case .idle: nil
            case .running: Self.runningText
            case .droppedResults: Self.droppedResultsText
            }
        let saveText = saveFailure.map { "Not saved: \($0)" }
        window?.subtitle = [saveText, runText].compactMap { $0 }.joined(separator: " · ")
    }
}
