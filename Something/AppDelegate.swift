import HotKey
import Cocoa
import SwiftUI

// Remove NSWindowDelegate conformance from AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var myHotKey: HotKey?
    var window: NSWindow? // Keep a reference to the window
    // Add a strong reference to the new window controller
    var windowController: SomethingWindowController?
    // Tests replace the catalog to avoid scanning the real application folders.
    var applicationCatalog = ApplicationCatalog.makeDefault()
    // The launcher shows the previous scan immediately, because scanning the
    // folders on the main thread delays the window after the hotkey.
    private var cachedApplications: [LaunchableApplication] = []
    private var launcherViewModel: LauncherViewModel?
    // A serial queue delivers scans in the order they started, so a slow
    // older scan never overwrites a newer result.
    private let applicationScanQueue = DispatchQueue(
        label: "com.garaemon.Something.applicationScan", qos: .userInitiated)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Change the activation policy to .accessory
        // This allows the app to become active and its windows to gain/lose focus,
        // while still keeping it out of the Dock.
        NSApplication.shared.setActivationPolicy(.accessory)
        refreshApplicationsInBackground()

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
            contentRect: NSRect(origin: .zero, size: LauncherView.minimumSize),
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
            self?.launcherViewModel = nil
        }

        newWindow.contentView = NSHostingView(rootView: makeLauncherView(in: newWindow))
        // Rescan on every open so that newly installed applications reach the
        // open launcher when the scan finishes.
        refreshApplicationsInBackground()

        // Activate before ordering the window front so that the window becomes
        // key and the query field can take keyboard focus.
        NSApplication.shared.activate()
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow // Store reference to the new window
        self.windowController = newWindowController // Store strong reference to the controller
    }

    private func makeLauncherView(in window: NSWindow) -> LauncherView {
        let viewModel = LauncherViewModel(
            applications: cachedApplications, launchApplication: launchApplication)
        launcherViewModel = viewModel
        return LauncherView(viewModel: viewModel, dismiss: { [weak window] in window?.close() })
    }

    private func refreshApplicationsInBackground() {
        let catalog = applicationCatalog
        applicationScanQueue.async { [weak self] in
            let applications = catalog.loadApplications()
            DispatchQueue.main.async {
                self?.cachedApplications = applications
                self?.launcherViewModel?.replaceApplications(applications)
            }
        }
    }

    private func launchApplication(_ application: LaunchableApplication) {
        NSWorkspace.shared.openApplication(
            at: application.url, configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            guard let error else { return }
            NSLog("Failed to launch %@: %@", application.url.path, error.localizedDescription)
        }
    }
}
