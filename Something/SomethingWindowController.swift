//
//  SomethingWindowController.swift
//  Something
//
//  Created by Ryohei Ueda on 2025/05/18.
//

import Cocoa

class SomethingWindowController: NSObject, NSWindowDelegate {
    // A closure to be called when the window should be released (e.g., hidden or closed).
    var onWindowRelease: (() -> Void)?
    // A child window follows its parent's moves but not its resizes, so the owner
    // of such a window repositions it here.
    var onWindowResize: (() -> Void)?

    // MARK: - NSWindowDelegate Methods

    // This method is called when the window resigns its key status (loses focus).
    func windowDidResignKey(_ notification: Notification) {
        // Hide the window when it loses focus.
        (notification.object as? NSWindow)?.orderOut(nil)
        // Trigger the release action via the closure.
        onWindowRelease?()
    }

    func windowDidResize(_ notification: Notification) {
        onWindowResize?()
    }

    // This method is called when the user clicks the close button.
    func windowWillClose(_ notification: Notification) {
        // Trigger the release action via the closure.
        onWindowRelease?()
    }
}
