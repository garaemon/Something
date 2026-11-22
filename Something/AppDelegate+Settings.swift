import Cocoa
import SwiftUI

extension AppDelegate {
    /// Shows the settings window, creating it on first use.
    func openSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        if window.contentView == nil {
            window.contentView = makeSettingsContentView()
        }
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = SettingsSource.candidateName
        // Kept alive by `settingsWindow` so that a reopen keeps its position.
        window.isReleasedWhenClosed = false
        window.contentView = makeSettingsContentView()
        window.center()
        // Drops the content of the closed window. The mascot preview inside
        // keeps SceneKit's render loop running for as long as the view lives.
        settingsWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            MainActor.assumeIsolated { window?.contentView = nil }
        }
        return window
    }

    private func makeSettingsContentView() -> NSView {
        NSHostingView(rootView: SettingsView(settings: settings))
    }
}
