import Foundation

/// Saves the latest text once the user pauses typing for `delay` seconds.
///
/// The save runs on the main thread.
@MainActor
final class ScratchAutosaver {
    private let delay: TimeInterval
    private let saveText: (String) -> Bool
    private var pendingText: String?
    private var pendingSave: DispatchWorkItem?

    /// `saveText` returns whether the save succeeded. A failed save keeps the text pending.
    init(delay: TimeInterval = 1, saveText: @escaping (String) -> Bool) {
        self.delay = delay
        self.saveText = saveText
    }

    /// Replaces the text to save, and restarts the wait for a pause.
    func scheduleSave(_ text: String) {
        pendingText = text
        pendingSave?.cancel()
        let save = DispatchWorkItem { [weak self] in self?.flush() }
        pendingSave = save
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: save)
    }

    /// Saves the pending text now, if any, so that nothing is lost when the window closes.
    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let text = pendingText else {
            return
        }
        // A failed save stays pending, so that the next flush, such as on quit, tries again.
        if saveText(text) {
            pendingText = nil
        }
    }
}
