import Cocoa
import SwiftUI

/// Owns the settings window and reuses it across opens.
@MainActor
final class SettingsWindowPresenter {
    private(set) var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    // Read on every show, because tests replace the delegate's settings after
    // the presenter exists.
    private let readSettings: () -> AppSettings

    init(readSettings: @escaping () -> AppSettings) {
        self.readSettings = readSettings
    }

    /// Shows the settings window, creating it on first use.
    func show() {
        let shownWindow = window ?? makeWindow()
        window = shownWindow
        if shownWindow.contentView == nil {
            shownWindow.contentView = makeContentView()
        }
        NSApplication.shared.activate()
        shownWindow.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let newWindow = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = SettingsSource.candidateName
        // Kept alive by `window` so that a reopen keeps its position.
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView = makeContentView()
        newWindow.center()
        // Drops the content of the closed window. The mascot preview inside
        // keeps SceneKit's render loop running for as long as the view lives.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newWindow,
            queue: .main
        ) { [weak newWindow] _ in
            MainActor.assumeIsolated { newWindow?.contentView = nil }
        }
        return newWindow
    }

    private func makeContentView() -> NSView {
        NSHostingView(rootView: SettingsView(settings: readSettings()))
    }
}
