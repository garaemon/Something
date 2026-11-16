import Foundation

/// Saves the latest text once the user pauses typing for `delay` seconds.
///
/// Every call happens on the main thread, and the save runs on the main thread too.
final class ScratchAutosaver {
    private let delay: TimeInterval
    private let saveText: (String) -> Void
    private var pendingText: String?
    private var pendingSave: DispatchWorkItem?

    init(delay: TimeInterval = 1, saveText: @escaping (String) -> Void) {
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
        pendingText = nil
        saveText(text)
    }
}
