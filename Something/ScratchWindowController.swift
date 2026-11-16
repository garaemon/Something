import AppKit

/// Owns the scratch window: a plain-text editor of Python source that saves itself.
///
/// The window survives a close, so that a reopen keeps its position and undo history.
@MainActor
final class ScratchWindowController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    static let windowTitle = "*scratch*"

    let window: NSWindow
    let textView: NSTextView
    private let autosaver: ScratchAutosaver

    init(store: ScratchStore) {
        let scrollView = NSTextView.scrollableTextView()
        guard let scrollingTextView = scrollView.documentView as? NSTextView else {
            preconditionFailure("NSTextView.scrollableTextView() holds no text view.")
        }
        textView = scrollingTextView
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        autosaver = ScratchAutosaver(saveText: { text in
            do {
                try store.saveText(text)
            } catch {
                NSLog("Saving the scratch buffer to %@ failed: %@", store.fileURL.path, "\(error)")
            }
        })
        super.init()
        Self.configureForCode(textView)
        textView.string = store.loadText()
        textView.delegate = self
        window.title = Self.windowTitle
        window.isReleasedWhenClosed = false
        window.contentView = scrollView
        window.delegate = self
        window.center()
    }

    /// Brings the window to the front with the keyboard focus in the editor.
    func show() {
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
    }

    func textDidChange(_ notification: Notification) {
        autosaver.scheduleSave(textView.string)
    }

    func windowWillClose(_ notification: Notification) {
        autosaver.flush()
    }

    /// Saves the pending edits now, such as when the app quits.
    func saveNow() {
        autosaver.flush()
    }

    // Smart quotes and dashes would turn Python source into syntax errors.
    private static func configureForCode(_ textView: NSTextView) {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
    }
}
