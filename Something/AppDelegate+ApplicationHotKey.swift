import AppKit

extension AppDelegate {
    /// Launches, activates, or cycles the windows of an application, as
    /// `ApplicationHotKeyPlanner` decides.
    func openApplication(_ target: ApplicationTarget) {
        let runningApplication = Self.findRunningApplication(for: target)
        guard let runningApplication else {
            launchApplication(target)
            return
        }
        let isFrontmost = NSWorkspace.shared.frontmostApplication == runningApplication
        let catalog = windowCatalog
        let processIdentifier = runningApplication.processIdentifier
        // The Accessibility calls can block, so they stay off the main thread.
        windowListQueue.async {
            let windows = catalog.loadWindows().filter { $0.processIdentifier == processIdentifier }
            let action = ApplicationHotKeyPlanner.plan(
                isRunning: true,
                isFrontmost: isFrontmost,
                windowCount: windows.count
            )
            DispatchQueue.main.async {
                Self.perform(action, on: runningApplication, windows: windows)
            }
        }
    }

    private func launchApplication(_ target: ApplicationTarget) {
        NSWorkspace.shared.openApplication(
            at: target.url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error { NSLog("Failed to launch %@: %@", target.path, "\(error)") }
        }
    }

    private static func findRunningApplication(
        for target: ApplicationTarget
    ) -> NSRunningApplication? {
        let runningApplications = NSWorkspace.shared.runningApplications
        return runningApplications.first { $0.bundleURL?.path == target.path }
            ?? runningApplications.first {
                target.bundleIdentifier != nil && $0.bundleIdentifier == target.bundleIdentifier
            }
    }

    private static func perform(
        _ action: ApplicationHotKeyAction,
        on application: NSRunningApplication,
        windows: [SwitchableWindow]
    ) {
        switch action {
        case .launch, .activate:
            // WindowRaiser switches applications more reliably than activate()
            // under cooperative activation, so it handles a first window too.
            if let frontWindow = windows.first {
                WindowRaiser.raiseWindow(frontWindow)
            } else {
                application.activate()
            }
        case .raiseWindow(let index):
            guard windows.indices.contains(index) else { return }
            WindowRaiser.raiseWindow(windows[index])
        }
    }
}
