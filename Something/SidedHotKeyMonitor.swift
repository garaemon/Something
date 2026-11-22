import Combine
import Foundation

/// A key-down event that the event tap reports.
struct TappedKeyEvent {
    let keyCode: UInt32
    /// Raw `CGEventFlags`, including the device-dependent left and right bits.
    let flags: UInt64
    let isAutorepeat: Bool
}

/// Installs and removes a tap on key-down events. A protocol, so that tests
/// never install a real tap, which would swallow the developer's keystrokes.
@MainActor
protocol KeyEventTapInstalling: AnyObject {
    /// Starts calling `handler` on the main thread for each key-down event, and
    /// swallows the event when `handler` returns true. Returns false when macOS
    /// refuses the tap.
    func install(handler: @escaping @MainActor (TappedKeyEvent) -> Bool) -> Bool

    func uninstall()
}

/// What the settings window tells about the sided hot keys.
enum SidedHotKeyStatus: Equatable {
    /// No binding needs a side, so no tap runs.
    case inactive
    case active
    /// The sided bindings wait for the Accessibility permission.
    case needsAccessibility
    case tapUnavailable
}

/// Runs the bindings that need a left or right modifier, through an event tap.
/// Bindings without a side stay with Carbon, which needs no permission.
@MainActor
final class SidedHotKeyMonitor: ObservableObject {
    @Published private(set) var status: SidedHotKeyStatus = .inactive
    /// While true, every event passes through, so that the settings window can
    /// record a new hot key.
    var isPaused = false

    private let installer: KeyEventTapInstalling
    private let isAccessibilityTrusted: () -> Bool
    private let runCommand: (HotKeyCommand) -> Void
    private var sidedBindings: [HotKeyBinding] = []
    private var isTapInstalled = false

    init(
        installer: KeyEventTapInstalling,
        isAccessibilityTrusted: @escaping () -> Bool,
        runCommand: @escaping (HotKeyCommand) -> Void
    ) {
        self.installer = installer
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.runCommand = runCommand
    }

    /// Watches for the sided bindings among `bindings`.
    func update(bindings: [HotKeyBinding]) {
        sidedBindings = bindings.filter { $0.modifierSides.isSided }
        refresh()
    }

    /// Installs or removes the tap to match the sided bindings and the
    /// Accessibility permission. Call it again after the user may have granted
    /// the permission.
    func refresh() {
        guard !sidedBindings.isEmpty else {
            removeTap()
            status = .inactive
            return
        }
        guard isAccessibilityTrusted() else {
            removeTap()
            status = .needsAccessibility
            return
        }
        if !isTapInstalled {
            isTapInstalled = installer.install(handler: { [weak self] event in
                self?.handle(event) ?? false
            })
        }
        status = isTapInstalled ? .active : .tapUnavailable
    }

    /// Returns true when `event` triggers a sided binding, so that the tap
    /// swallows it. The command runs on a later turn of the run loop, because
    /// macOS disables a tap whose handler is slow.
    func handle(_ event: TappedKeyEvent) -> Bool {
        guard !isPaused else { return false }
        let matchingBinding = sidedBindings.first {
            HotKeyEventMatcher.matches(
                keyCode: event.keyCode,
                flags: event.flags,
                keyCombo: $0.keyCombo,
                sides: $0.modifierSides
            )
        }
        guard let matchingBinding else { return false }
        if !event.isAutorepeat {
            let command = matchingBinding.command
            Task { @MainActor [weak self] in self?.runCommand(command) }
        }
        return true
    }

    private func removeTap() {
        guard isTapInstalled else { return }
        installer.uninstall()
        isTapInstalled = false
    }
}
