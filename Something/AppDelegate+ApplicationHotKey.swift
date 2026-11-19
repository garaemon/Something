import AppKit

extension AppDelegate {
    /// Launches, activates, or cycles the windows of an application, as
    /// `ApplicationHotKeyPlanner` decides.
    func openApplication(_ target: ApplicationTarget) {
        guard let runningApplication = Self.findRunningApplication(for: target) else {
            let action = ApplicationHotKeyPlanner.plan(
                isRunning: false,
                isFrontmost: false,
                windowCount: 0
            )
            runApplicationHotKeyAction(action, target: target, windows: [])
            return
        }
        let isFrontmost = NSWorkspace.shared.frontmostApplication == runningApplication
        let catalog = windowCatalog
        let processIdentifier = runningApplication.processIdentifier
        // The Accessibility calls can block, so they stay off the main thread.
        windowListQueue.async { [weak self] in
            let windows = catalog.loadWindows().filter { $0.processIdentifier == processIdentifier }
            let action = ApplicationHotKeyPlanner.plan(
                isRunning: true,
                isFrontmost: isFrontmost,
                windowCount: windows.count
            )
            DispatchQueue.main.async {
                self?.runApplicationHotKeyAction(
                    action,
                    target: target,
                    windows: windows
                )
            }
        }
    }

    private func launchApplication(_ target: ApplicationTarget) {
        // The bundle identifier finds an application that moved since the
        // user picked it.
        let applicationURL =
            FileManager.default.fileExists(atPath: target.path)
            ? target.url
            : target.bundleIdentifier.flatMap {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
            }
        guard let applicationURL else {
            NSLog("Application not found: %@", target.path)
            return
        }
        NSWorkspace.shared.openApplication(
            at: applicationURL,
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

    private func runApplicationHotKeyAction(
        _ action: ApplicationHotKeyAction,
        target: ApplicationTarget,
        windows: [SwitchableWindow]
    ) {
        switch action {
        case .launch:
            launchApplication(target)
        case .activate:
            // WindowRaiser switches applications more reliably than activate()
            // under cooperative activation, so it handles a first window too.
            if let frontWindow = windows.first {
                WindowRaiser.raiseWindow(frontWindow)
            } else {
                // activate() alone neither fronts the application under cooperative
                // activation nor reopens a window, so reopen it through NSWorkspace.
                launchApplication(target)
            }
        case .raiseWindow(let index):
            guard windows.indices.contains(index) else { return }
            WindowRaiser.raiseWindow(windows[index])
        }
    }
}
