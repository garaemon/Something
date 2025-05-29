import HotKey
import Cocoa
import SwiftUI // Import SwiftUI to host ContentView

class AppDelegate: NSObject, NSApplicationDelegate {
    var myHotKey: HotKey?
    var window: NSWindow? // Keep a reference to the window

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set activation policy to prevent the app from appearing in the Dock or menu bar by default.
        NSApplication.shared.setActivationPolicy(.prohibited)

        // Bind Command + Shift + x
        myHotKey = HotKey(key: .x, modifiers: [.command, .shift])
        myHotKey?.keyDownHandler = { [weak self] in
            self?.openWindow()
        }
    }

    func openWindow() {
        // If the window already exists and is visible, bring it to the front.
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        // Create a new window if it doesn't exist or was closed.
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        newWindow.center()
        newWindow.setFrameAutosaveName("SomethingWindow")
        // Keep the window in memory when closed by the user (it just becomes hidden).
        // This allows the hotkey to bring it back without recreating it.
        newWindow.isReleasedWhenClosed = false

        // Host the SwiftUI view in the window
        newWindow.contentView = NSHostingView(rootView: ContentView())

        // Make the window key and order front
        newWindow.makeKeyAndOrderFront(nil)

        // Activate the application to bring it to the foreground and give focus to the window
        NSApplication.shared.activate(ignoringOtherApps: true)

        self.window = newWindow // Store reference to the new window
    }
}
