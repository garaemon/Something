import Foundation
import HotKey

extension AppDelegate {
    /// Replaces every registered hot key with one per binding. Bindings that
    /// need a left or right modifier go to the sided hot key monitor instead,
    /// because Carbon cannot tell the sides apart.
    func registerHotKeys(_ bindings: [HotKeyBinding]) {
        sidedHotKeyMonitor.update(bindings: bindings)
        // Releasing the old HotKeys first unregisters them from Carbon, so that a
        // binding that keeps its combination does not register it twice.
        registeredHotKeys = []
        registeredHotKeys = bindings.filter { !$0.modifierSides.isSided }.map { binding in
            let hotKey = HotKey(keyCombo: binding.keyCombo)
            let command = binding.command
            hotKey.keyDownHandler = { [weak self] in self?.run(command) }
            hotKey.isPaused = settings.isRecordingHotKey
            return hotKey
        }
    }

    /// Tries the sided hot keys again, because the user may have granted the
    /// Accessibility permission in System Settings while the app was in the background.
    func applicationDidBecomeActive(_ notification: Notification) {
        sidedHotKeyMonitor.refresh()
    }

    /// Runs the command of a hot key binding.
    func run(_ command: HotKeyCommand) {
        switch command {
        case .openLauncher: openWindow()
        case .openScratch: openScratch()
        case .openSettings: openSettings()
        }
    }
}
