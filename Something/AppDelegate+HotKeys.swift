import HotKey

extension AppDelegate {
    func registerHotKeys(_ bindings: [HotKeyBinding]) {
        // Releasing the old HotKeys unregisters them from Carbon.
        registeredHotKeys = []
        registeredHotKeys = bindings.map { binding in
            let hotKey = HotKey(keyCombo: binding.keyCombo)
            let command = binding.command
            hotKey.keyDownHandler = { [weak self] in self?.run(command) }
            hotKey.isPaused = settings.isRecordingHotKey
            return hotKey
        }
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
