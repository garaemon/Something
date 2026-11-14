import ApplicationServices

/// Brings windows of other applications to the front.
enum WindowRaiser {
    /// Restores `window` if minimized, raises it above the other windows of
    /// its application, and makes that application frontmost.
    ///
    /// Fails silently when the window has closed or the Accessibility
    /// permission is missing.
    static func raiseWindow(_ window: SwitchableWindow) {
        AXUIElementSetAttributeValue(window.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        // NSRunningApplication.activate() returns true but leaves the previous
        // app in front under macOS 14 cooperative activation. Setting the AX
        // frontmost attribute switches the app reliably.
        let applicationElement = AXUIElementCreateApplication(window.processIdentifier)
        AXUIElementSetAttributeValue(
            applicationElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }
}
