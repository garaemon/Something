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
            NSApplication.shared.activate()
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        newWindow.center()
        newWindow.setFrameAutosaveName("SomethingWindow")
        // ARC owns the window through `window`. Letting AppKit also release it on
        // close over-releases it and crashes when the autorelease pool drains.
        newWindow.isReleasedWhenClosed = false
        
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

        newWindow.contentView = NSHostingView(rootView: makeLauncherView(in: newWindow))

        // Activate before ordering the window front so that the window becomes
        // key and the query field can take keyboard focus.
        NSApplication.shared.activate()
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow // Store reference to the new window
        self.windowController = newWindowController // Store strong reference to the controller
    }

    private func makeLauncherView(in window: NSWindow) -> LauncherView {
        // Rescan on every open so that newly installed applications show up.
        let viewModel = LauncherViewModel(
            applications: ApplicationCatalog.makeDefault().loadApplications(),
            launchApplication: { application in
                NSWorkspace.shared.openApplication(
                    at: application.url, configuration: NSWorkspace.OpenConfiguration())
            })
        return LauncherView(viewModel: viewModel, dismiss: { [weak window] in window?.close() })
    }
}
