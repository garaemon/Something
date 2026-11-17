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
}
