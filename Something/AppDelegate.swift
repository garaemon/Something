import HotKey
import Cocoa
import SwiftUI

// Remove NSWindowDelegate conformance from AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var myHotKey: HotKey?
    var window: NSWindow? // Keep a reference to the window
    // Add a strong reference to the new window controller
    var windowController: SomethingWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Change the activation policy to .accessory
        // This allows the app to become active and its windows to gain/lose focus,
        // while still keeping it out of the Dock.
        NSApplication.shared.setActivationPolicy(.accessory)

        myHotKey = HotKey(key: .x, modifiers: [.command, .shift])
        myHotKey?.keyDownHandler = { [weak self] in
            self?.openWindow()
        }
    }

    func openWindow() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        newWindow.center()
        newWindow.setFrameAutosaveName("SomethingWindow")
        newWindow.isReleasedWhenClosed = true
        
        // Add this line to disable window restoration for this window
        newWindow.restorationClass = nil 

        // Create an instance of the new window controller
        let newWindowController = SomethingWindowController()
        // Set the delegate of the new window to the new controller instance
        newWindow.delegate = newWindowController
        
        // Set the closure for when the window should be released
        newWindowController.onWindowRelease = { [weak self] in
            // When the window is released (hidden/closed), nil out the references
            self?.window?.orderOut(nil) // Ensure it's hidden if not already
            self?.window = nil
            self?.windowController = nil // Release the strong reference to the controller
        }

        newWindow.contentView = NSHostingView(rootView: ContentView())

        newWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        self.window = newWindow // Store reference to the new window
        self.windowController = newWindowController // Store strong reference to the controller
    }

    // MARK: - NSWindowDelegate Methods (These are now handled by SomethingWindowController)
    // Remove windowDidResignKey and windowWillClose from here.
}
