import AppKit
import ApplicationServices

/// Brings windows of other applications to the front.
enum WindowRaiser {
    /// Restores `window` if minimized, raises it above the other windows of
    /// its application, and activates that application.
    ///
    /// Fails silently when the window has closed or the Accessibility
    /// permission is missing; the application is still activated.
    static func raiseWindow(_ window: SwitchableWindow) {
        AXUIElementSetAttributeValue(window.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        guard let application = NSRunningApplication(processIdentifier: window.processIdentifier) else {
            return
        }
        // macOS 14 activation is cooperative: the active app must yield,
        // or the target app may refuse to come to the front.
        NSApplication.shared.yieldActivation(to: application)
        application.activate()
    }
}
