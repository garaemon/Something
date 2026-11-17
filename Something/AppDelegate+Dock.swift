import Cocoa

extension AppDelegate {
    /// Opens the launcher when the user clicks the app's Dock icon, or opens the
    /// app again from Finder, while the app is running.
    ///
    /// - Returns: `false`, because the launcher replaces the stock behavior of
    ///   restoring a minimized window.
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        openWindow()
        return false
    }

    /// Shows the Dock icon for `.regular` and hides it for `.accessory`, and
    /// keeps the key window, such as the settings window, in front.
    static func switchActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        let keyWindow = NSApplication.shared.keyWindow
        NSApplication.shared.setActivationPolicy(policy)
        guard let keyWindow else { return }
        // Switching to .accessory deactivates the app, which would send the
        // settings window behind other apps while the user flips the toggle.
        NSApplication.shared.activate()
        keyWindow.makeKeyAndOrderFront(nil)
    }
}
