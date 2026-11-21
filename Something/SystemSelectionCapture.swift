import AppKit
import ApplicationServices
import Carbon.HIToolbox

extension SelectionCapturer {
    /// Returns a capturer wired to the system: the frontmost application of
    /// `NSWorkspace`, the Accessibility API, the general pasteboard, and a
    /// synthetic Cmd+C.
    static func makeDefault() -> SelectionCapturer {
        SelectionCapturer(
            readFrontmostApplication: SystemSelectionServices.readFrontmostApplication,
            readAccessibilitySelection: SystemSelectionServices.readAccessibilitySelection,
            pasteboard: GeneralSelectionPasteboard(),
            canPostCopyKey: { AXIsProcessTrusted() },
            postCopyKey: SystemSelectionServices.postCopyKey,
            pauseBetweenPolls: { Thread.sleep(forTimeInterval: 0.01) },
            maximumPollCount: 30,
            ownProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )
    }
}

private struct GeneralSelectionPasteboard: SelectionPasteboard {
    private var pasteboard: NSPasteboard { .general }

    var changeCount: Int { pasteboard.changeCount }

    func readSnapshot() -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.reduce(into: [String: Data]()) { representations, type in
                representations[type.rawValue] = item.data(forType: type)
            }
        }
        return PasteboardSnapshot(items: items)
    }

    func readString() -> String? { pasteboard.string(forType: .string) }

    func restore(_ snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        let items = snapshot.items.map { representations -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in representations {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        pasteboard.writeObjects(items)
    }
}

private enum SystemSelectionServices {
    private static let copyKeyCode = CGKeyCode(kVK_ANSI_C)

    static func readFrontmostApplication() -> SourceApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        return SourceApplication(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            name: application.localizedName ?? ""
        )
    }

    static func readAccessibilitySelection(of application: SourceApplication) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, AccessibilityMessaging.timeoutSeconds)
        var focusedValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                applicationElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            )
                == .success,
            let focusedValue,
            CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else {
            return nil
        }
        // The type ID check above guarantees the cast.
        let focusedElement = focusedValue as! AXUIElement  // swiftlint:disable:this force_cast
        AXUIElementSetMessagingTimeout(focusedElement, AccessibilityMessaging.timeoutSeconds)
        var selectedValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                focusedElement,
                kAXSelectedTextAttribute as CFString,
                &selectedValue
            ) == .success
        else {
            return nil
        }
        return selectedValue as? String
    }

    /// Posting a key event needs the Accessibility permission. Without it the
    /// event is dropped silently, so the caller must not wait for a copy.
    static func postCopyKey() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        // The hot key fires on key down, so the user still holds its modifiers.
        // A private state keeps them out of the event: Cmd+Shift+C would not copy.
        let source = CGEventSource(stateID: .privateState)
        guard
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: copyKeyCode,
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: copyKeyCode,
                keyDown: false
            )
        else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
