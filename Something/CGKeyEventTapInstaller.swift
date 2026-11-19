import ApplicationServices
import CoreGraphics

/// Installs a session event tap on key-down events through Core Graphics.
/// Swallowing events needs the Accessibility permission. Not unit tested,
/// because a real tap would intercept the keystrokes of the developer.
@MainActor
final class CGKeyEventTapInstaller: KeyEventTapInstalling {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handlerBox: Unmanaged<TapHandlerBox>?

    /// Returns true when the Accessibility permission is granted. Never prompts,
    /// because `WindowCatalog` already asks once.
    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func install(handler: @escaping @MainActor (TappedKeyEvent) -> Bool) -> Bool {
        uninstall()
        let tapHandler = TapHandlerBox(handler: handler)
        tapHandler.installer = self
        let box = Unmanaged.passRetained(tapHandler)
        let keyDownMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: keyDownMask,
                callback: Self.handleTappedEvent,
                userInfo: box.toOpaque()
            )
        else {
            box.release()
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        handlerBox = box
        return true
    }

    func uninstall() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        handlerBox?.release()
        handlerBox = nil
    }

    // The run loop source sits on the main run loop, so the callback runs on
    // the main thread.
    private static let handleTappedEvent: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let box = Unmanaged<TapHandlerBox>.fromOpaque(userInfo).takeUnretainedValue()
        return MainActor.assumeIsolated { box.process(type: type, event: event) }
    }
}

/// Carries the handler through the C callback's user data.
private final class TapHandlerBox {
    let handler: @MainActor (TappedKeyEvent) -> Bool
    weak var installer: CGKeyEventTapInstaller?

    init(handler: @escaping @MainActor (TappedKeyEvent) -> Bool) {
        self.handler = handler
    }

    @MainActor
    func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            installer?.reenable()
            return Unmanaged.passUnretained(event)
        case .keyDown:
            let tappedEvent = TappedKeyEvent(
                keyCode: UInt32(event.getIntegerValueField(.keyboardEventKeycode)),
                flags: event.flags.rawValue,
                isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            )
            return handler(tappedEvent) ? nil : Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

extension CGKeyEventTapInstaller {
    /// Turns the tap on again after macOS disabled it. macOS does so when a
    /// handler is too slow, or when the user types a secure input field.
    func reenable() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}
