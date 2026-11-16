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
    // Kept apart from `textView.isEditable`, which a run of the code may also turn off.
    private var isShowingFile = true

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
        // The subtitle stays until a later save succeeds, so that a failure does not go unseen.
        autosaver = ScratchAutosaver(saveText: { [weak window] text in
            do {
                try store.saveText(text)
                window?.subtitle = ""
                return true
            } catch {
                // The log also covers a save on close or on quit, where no subtitle shows.
                NSLog("Saving the scratch buffer to %@ failed: %@", store.fileURL.path, "\(error)")
                window?.subtitle = "Not saved: \(error.localizedDescription)"
                return false
            }
        })
        super.init()
        Self.configureForCode(textView)
        loadText(from: store)
        textView.delegate = self
        window.title = Self.windowTitle
        window.isReleasedWhenClosed = false
        window.contentView = scrollView
        window.delegate = self
        window.center()
    }

    // A file that exists but cannot be read stays read-only, so that no autosave
    // replaces the content that the user may still recover.
    private func loadText(from store: ScratchStore) {
        do {
            textView.string = try store.loadText()
        } catch {
            textView.string =
                "# \(store.fileURL.path) cannot be read: \(error.localizedDescription)\n"
            textView.isEditable = false
            isShowingFile = false
        }
    }

    /// Returns this controller when it shows the scratch file, and closes it and returns nil
    /// when it shows an error about reading the file, so that a new controller reads the file
    /// again in case the user fixed it.
    func reuseIfShowingFile() -> ScratchWindowController? {
        if isShowingFile {
            return self
        }
        window.close()
        return nil
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
