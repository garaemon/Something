import HotKey
import Cocoa
import SwiftUI

// Remove NSWindowDelegate conformance from AppDelegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var myHotKey: HotKey?
    var window: NSWindow? // Keep a reference to the window
    // Add a strong reference to the new window controller
    var windowController: SomethingWindowController?
    // The mascot stands on the launcher's top edge in a window of its own.
    private(set) var mascotPanel: MascotPanel?
    // Tests replace the catalog to avoid scanning the real application folders.
    var applicationCatalog = ApplicationCatalog.makeDefault()
    var windowCatalog = WindowCatalog.makeDefault()
    // The launcher shows the previous scan immediately, because scanning the
    // folders on the main thread delays the window after the hotkey.
    private var cachedApplications: [LaunchableApplication] = []
    private(set) var launcherViewModel: LauncherViewModel?
    // A serial queue delivers scans in the order they started, so a slow
    // older scan never overwrites a newer result.
    private let applicationScanQueue = DispatchQueue(
        label: "com.garaemon.Something.applicationScan", qos: .userInitiated)
    // Windows get their own queue so that a slow folder scan does not delay
    // the window list, which the user expects right after the hotkey.
    private let windowListQueue = DispatchQueue(
        label: "com.garaemon.Something.windowList", qos: .userInitiated)

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
            self?.closeMascotPanel()
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
        refreshWindowsInBackground()

        // Activate before ordering the window front so that the window becomes
        // key and the query field can take keyboard focus.
        NSApplication.shared.activate()
        newWindow.makeKeyAndOrderFront(nil)
        attachMascotPanel(to: newWindow, controller: newWindowController)

        self.window = newWindow // Store reference to the new window
        self.windowController = newWindowController // Store strong reference to the controller
    }

    // Attached after the launcher is ordered front so that the panel never competes
    // for key status; it also cannot become key by itself.
    private func attachMascotPanel(to launcher: NSWindow, controller: SomethingWindowController) {
        guard let viewModel = launcherViewModel else { return }
        let panel = MascotPanel.make(viewModel: viewModel, launcherFrame: launcher.frame)
        launcher.addChildWindow(panel, ordered: .above)
        mascotPanel = panel
        controller.onWindowResize = { [weak self, weak launcher] in
            guard let launcher else { return }
            self?.mascotPanel?.reposition(forLauncherFrame: launcher.frame)
        }
    }

    // Safe to call twice, because both close and resign-key release the window.
    private func closeMascotPanel() {
        guard let panel = mascotPanel else { return }
        mascotPanel = nil
        window?.removeChildWindow(panel)
        // Dropping the content stops the SceneKit view from rendering.
        panel.contentView = nil
        panel.orderOut(nil)
        panel.close()
    }

    private func makeLauncherView(in window: NSWindow) -> LauncherView {
        let viewModel = LauncherViewModel(
            applications: cachedApplications, launchApplication: launchApplication,
            raiseWindow: WindowRaiser.raiseWindow)
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

    // Windows are not cached, because they open, close, and change titles
    // far more often than applications are installed. A load that outlives
    // its launcher is dropped, because its windows may have closed since.
    private func refreshWindowsInBackground() {
        let catalog = windowCatalog
        let targetViewModel = launcherViewModel
        windowListQueue.async { [weak self] in
            let windows = catalog.loadWindows()
            DispatchQueue.main.async {
                guard let self, let targetViewModel,
                    self.launcherViewModel === targetViewModel
                else { return }
                targetViewModel.replaceWindows(windows)
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
