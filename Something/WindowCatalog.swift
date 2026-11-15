import AppKit
import ApplicationServices

/// Lists the windows of other running applications.
struct WindowCatalog {
    /// Returns the current windows. Runs on a background queue.
    let loadWindows: () -> [SwitchableWindow]

    /// Returns a catalog that reads windows through the Accessibility API.
    ///
    /// The first load asks the user for the Accessibility permission. Until
    /// the user grants it, every load returns no windows.
    static func makeDefault() -> WindowCatalog {
        let permissionPrompt = AccessibilityPermissionPrompt()
        return WindowCatalog(loadWindows: {
            guard permissionPrompt.checkTrustedPromptingOnce() else { return [] }
            return AccessibilityWindowReader.loadWindows()
        })
    }
}

/// Shows the system's Accessibility permission dialog at most once per
/// process, because the dialog would otherwise reappear on every hotkey.
private final class AccessibilityPermissionPrompt {
    private let lock = NSLock()
    private var hasPrompted = false

    func checkTrustedPromptingOnce() -> Bool {
        let shouldPrompt = lock.withLock {
            let isFirstCall = !hasPrompted
            hasPrompted = true
            return isFirstCall
        }
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): shouldPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

/// Limits how long an Accessibility call waits for another application.
enum AccessibilityMessaging {
    /// The timeout to give every AX element of another application. An
    /// application that does not answer, such as one stuck in a long task,
    /// would otherwise block the caller for the default 6 seconds.
    static let timeoutSeconds: Float = 0.25
}

private enum AccessibilityWindowReader {
    static func loadWindows() -> [SwitchableWindow] {
        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular && $0.processIdentifier != ownProcessIdentifier
            }
            .flatMap(loadWindows(of:))
    }

    private static func loadWindows(of application: NSRunningApplication) -> [SwitchableWindow] {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, AccessibilityMessaging.timeoutSeconds)
        guard
            let windowElements = copyAttribute(kAXWindowsAttribute, of: applicationElement)
                as? [AXUIElement]
        else {
            return []
        }
        // Use the bundle file name, as the application list does, so that
        // one query matches both an application and its windows.
        let applicationName =
            application.bundleURL?.deletingPathExtension().lastPathComponent
            ?? application.localizedName ?? ""
        return windowElements.compactMap { windowElement in
            AXUIElementSetMessagingTimeout(windowElement, AccessibilityMessaging.timeoutSeconds)
            guard
                copyAttribute(kAXSubroleAttribute, of: windowElement) as? String
                    == kAXStandardWindowSubrole,
                let title = copyAttribute(kAXTitleAttribute, of: windowElement) as? String,
                !title.isEmpty
            else {
                return nil
            }
            return SwitchableWindow(
                applicationName: applicationName,
                title: title,
                processIdentifier: application.processIdentifier,
                element: windowElement
            )
        }
    }

    private static func copyAttribute(_ attribute: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else {
            return nil
        }
        return value
    }
}
