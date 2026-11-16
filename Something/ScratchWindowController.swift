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
    private let subtitle: ScratchSubtitle
    private let highlighter: ScratchHighlighter
    // Kept apart from `textView.isEditable`, which a run of the code may also turn off.
    private var isShowingFile = true
    private var runner: ScratchRunner?
    /// The Run buttons of the blocks, or nil when the window could not read the scratch file.
    private(set) var runButtons: ScratchRunButtons?
    private var keyBindings = ScratchKeyBindings()
    private var keyMonitor: Any?

    /// Called on the main thread after a run or a reset ends. A window that could not read the
    /// scratch file runs nothing, and drops the closure.
    var onRunFinished: (() -> Void)? {
        get { runner?.onRunFinished }
        set { runner?.onRunFinished = newValue }
    }

    /// `makeRunner` builds the runner of the blocks in the text view. Tests pass a runner
    /// with a fake interpreter.
    init(
        store: ScratchStore,
        makeRunner: @MainActor (NSTextView) -> ScratchRunner = { ScratchRunner(textView: $0) }
    ) {
        let scrollView = NSTextView.scrollableTextView()
        guard let scrollingTextView = scrollView.documentView as? NSTextView else {
            preconditionFailure("NSTextView.scrollableTextView() holds no text view.")
        }
        textView = scrollingTextView
        highlighter = ScratchHighlighter(textView: scrollingTextView)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        // The failure stays in the subtitle until a later save succeeds, so that it does not
        // go unseen.
        let subtitle = ScratchSubtitle(window: window)
        self.subtitle = subtitle
        autosaver = ScratchAutosaver(saveText: { text in
            do {
                try store.saveText(text)
                subtitle.saveFailure = nil
                return true
            } catch {
                // The log also covers a save on close or on quit, where no subtitle shows.
                NSLog("Saving the scratch buffer to %@ failed: %@", store.fileURL.path, "\(error)")
                subtitle.saveFailure = error.localizedDescription
                return false
            }
        })
        super.init()
        Self.configureForCode(textView)
        loadText(from: store)
        runner = isShowingFile ? makeRunner(textView) : nil
        runner?.onStatusChanged = { status in subtitle.runStatus = status }
        textView.delegate = self
        window.title = Self.windowTitle
        window.isReleasedWhenClosed = false
        window.contentView = scrollView
        window.delegate = self
        window.center()
        if runner != nil {
            runButtons = ScratchRunButtons(textView: textView) { [weak self] lineIndex in
                self?.runBlockUnlessComposing(atLine: lineIndex)
            }
        }
        highlighter.update()
        runButtons?.update()
    }

    // A click does not commit the text that an input method composes, and C-j skips a run
    // then too.
    private func runBlockUnlessComposing(atLine lineIndex: Int) {
        guard !textView.hasMarkedText() else {
            return
        }
        runner?.runBlock(atLine: lineIndex)
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
        startMonitoringKeys()
    }

    /// Runs the scratch command of a key press in the editor, and returns nil to consume the
    /// press, or returns the event for the text view to handle.
    func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        // An input method that composes text, such as Japanese kana, uses C-j and C-c.
        guard let runner, !textView.hasMarkedText(),
            let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return event
        }
        let modifiers = event.modifierFlags.intersection([.control, .option, .command, .shift])
        switch keyBindings.resolve(key: key, isControlOnly: modifiers == .control) {
        case .command(let command):
            runner.perform(command)
            return nil
        case .prefix, .swallowed:
            return nil
        case .passThrough:
            return event
        }
    }

    // A local monitor sees the keys before the text view, which would insert a newline
    // for C-j, without subclassing NSTextView.
    private func startMonitoringKeys() {
        guard keyMonitor == nil else {
            return
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, event.window === self.window,
                    self.window.firstResponder === self.textView
                else {
                    return event
                }
                return self.handleKeyDown(event)
            }
        }
    }

    private func stopMonitoringKeys() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    func textDidChange(_ notification: Notification) {
        autosaver.scheduleSave(textView.string)
        highlighter.update()
        runButtons?.update()
    }

    // A narrower window wraps long lines, which moves the blocks below them down.
    func windowDidResize(_ notification: Notification) {
        runButtons?.update()
    }

    func windowWillClose(_ notification: Notification) {
        stopMonitoringKeys()
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
